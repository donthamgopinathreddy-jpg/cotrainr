package com.cotrainr.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject

object WaterNotificationHelper {
    /** Versioned channel — old `water_reminders` settings cannot be changed in-place. */
    const val CHANNEL_ID = "cotrainr_hydration_reminders"
    const val CHANNEL_NAME = "Hydration reminders"
    const val CHANNEL_DESCRIPTION =
        "Reminders to drink water and log hydration."

    const val REMINDER_NOTIFICATION_ID = 9100
    const val TEST_NOTIFICATION_ID = 9099

    const val ACTION_ADD_250 = "water_add_250"
    const val ACTION_ADD_500 = "water_add_500"

    /** Fixed increments. Amounts are never read from intent extras. */
    private val ALLOWED_AMOUNTS = mapOf(
        ACTION_ADD_250 to 250,
        ACTION_ADD_500 to 500,
    )

    private const val ACTION_ALARM = "com.cotrainr.app.WATER_REMINDER_ALARM"

    private const val PREFS_NAME = "cotrainr_hydration"
    private const val KEY_CONSUMED_ML = "consumed_ml"
    private const val KEY_GOAL_ML = "goal_ml"
    private const val KEY_INTERVAL_MINUTES = "interval_minutes"
    private const val KEY_UPDATED_AT = "updated_at"
    private const val KEY_SNAPSHOT_DATE = "snapshot_local_date"
    private const val KEY_PENDING_LOGS = "pending_quick_logs_v1"
    private const val KEY_NEXT_TRIGGER_AT = "next_trigger_at"

    /** Guards the read-modify-write of the hydration total. */
    private val logLock = Any()

    // Matches DesignTokens.accentOrange
    private val ACCENT_ORANGE = Color.parseColor("#FF8A00")

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = CHANNEL_DESCRIPTION
            setShowBadge(false)
            enableLights(true)
            lightColor = ACCENT_ORANGE
        }
        manager.createNotificationChannel(channel)
    }

    // ------------------------------------------------------------------
    // Local calendar day
    // ------------------------------------------------------------------

    /**
     * `yyyy-MM-dd` in the device's *current* local timezone, matching
     * HydrationLocalStore.localDateKey on the Dart side. Recomputed on every
     * call so a timezone change takes effect immediately.
     */
    fun localDateKey(atMs: Long = System.currentTimeMillis()): String {
        val cal = Calendar.getInstance()
        cal.timeInMillis = atMs
        return "%04d-%02d-%02d".format(
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH),
        )
    }

    fun syncHydrationSnapshot(context: Context, consumedMl: Int, goalMl: Int) {
        synchronized(logLock) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putInt(KEY_CONSUMED_ML, consumedMl.coerceAtLeast(0))
                .putInt(KEY_GOAL_ML, goalMl.coerceAtLeast(0))
                .putString(KEY_SNAPSHOT_DATE, localDateKey())
                .putLong(KEY_UPDATED_AT, System.currentTimeMillis())
                .apply()
        }
    }

    // ------------------------------------------------------------------
    // Quick log (notification action) — atomic, no Activity launch
    // ------------------------------------------------------------------

    fun amountForAction(actionId: String?): Int? = ALLOWED_AMOUNTS[actionId]

    /**
     * Adds a fixed increment to today's total and queues a durable event for
     * Dart to reconcile. Returns the new total, or null if [actionId] is not a
     * recognised fixed increment.
     *
     * Runs entirely inside the broadcast receiver — no Activity, no Flutter
     * engine required. The lock plus `commit()` make back-to-back taps additive
     * rather than last-write-wins.
     */
    fun applyQuickLog(context: Context, actionId: String?): Int? {
        val amountMl = amountForAction(actionId) ?: return null

        synchronized(logLock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val nowMs = System.currentTimeMillis()
            val today = localDateKey(nowMs)

            // Roll over before adding so a tap after local midnight starts a new day.
            val storedDate = prefs.getString(KEY_SNAPSHOT_DATE, null)
            val base = if (storedDate == today) {
                prefs.getInt(KEY_CONSUMED_ML, 0).coerceAtLeast(0)
            } else {
                0
            }

            val next = (base + amountMl).coerceAtLeast(0)

            val pending = readPendingArray(prefs)
            pending.put(
                JSONObject()
                    .put("eventId", "native_${actionId}_${nowMs}_$amountMl")
                    .put("amountMl", amountMl)
                    .put("localDate", today)
                    .put("atMs", nowMs),
            )

            // commit(), not apply(): the process may be killed the moment the
            // receiver returns, and the increment must already be on disk.
            prefs.edit()
                .putInt(KEY_CONSUMED_ML, next)
                .putString(KEY_SNAPSHOT_DATE, today)
                .putLong(KEY_UPDATED_AT, nowMs)
                .putString(KEY_PENDING_LOGS, pending.toString())
                .commit()

            return next
        }
    }

    /** Events awaiting reconciliation by the Dart hydration store. */
    fun drainPendingQuickLogs(context: Context): List<Map<String, Any>> {
        synchronized(logLock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val pending = readPendingArray(prefs)
            val out = ArrayList<Map<String, Any>>(pending.length())
            for (i in 0 until pending.length()) {
                val item = pending.optJSONObject(i) ?: continue
                out.add(
                    mapOf(
                        "eventId" to item.optString("eventId"),
                        "amountMl" to item.optInt("amountMl"),
                        "localDate" to item.optString("localDate"),
                        "atMs" to item.optLong("atMs"),
                    ),
                )
            }
            return out
        }
    }

    /** Acknowledge events Dart has durably applied. */
    fun clearPendingQuickLogs(context: Context, eventIds: Collection<String>) {
        if (eventIds.isEmpty()) return
        synchronized(logLock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val pending = readPendingArray(prefs)
            val kept = JSONArray()
            for (i in 0 until pending.length()) {
                val item = pending.optJSONObject(i) ?: continue
                if (!eventIds.contains(item.optString("eventId"))) {
                    kept.put(item)
                }
            }
            prefs.edit().putString(KEY_PENDING_LOGS, kept.toString()).commit()
        }
    }

    private fun readPendingArray(
        prefs: android.content.SharedPreferences,
    ): JSONArray {
        val raw = prefs.getString(KEY_PENDING_LOGS, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    // ------------------------------------------------------------------
    // Notifications
    // ------------------------------------------------------------------

    fun show(
        context: Context,
        notificationId: Int,
        title: String? = null,
        body: String? = null,
        skipIfGoalComplete: Boolean = true,
    ) {
        createChannel(context)
        val snapshot = readSnapshot(context)
        if (skipIfGoalComplete && snapshot.goalReached) {
            showGoalComplete(context, notificationId, snapshot)
            return
        }
        val notification = buildHydrationNotification(
            context = context,
            notificationId = notificationId,
            titleOverride = title,
            bodyOverride = body,
            snapshot = snapshot,
            goalComplete = false,
        )
        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    /** AlarmManager entry — never nag after the daily goal is already hit. */
    fun showScheduledReminder(context: Context) {
        createChannel(context)
        val snapshot = readSnapshot(context)
        if (snapshot.goalReached) return
        show(context, REMINDER_NOTIFICATION_ID, skipIfGoalComplete = false)
    }

    /**
     * Re-post the reminder in place after a quick log so the user sees the new
     * total without the app opening. Same notification id, so no duplicate.
     */
    fun refreshAfterQuickLog(context: Context) {
        createChannel(context)
        val snapshot = readSnapshot(context)
        if (snapshot.goalReached) {
            showGoalComplete(context, REMINDER_NOTIFICATION_ID, snapshot)
            return
        }
        show(context, REMINDER_NOTIFICATION_ID, skipIfGoalComplete = false)
    }

    fun showGoalComplete(context: Context, notificationId: Int, snapshot: HydrationSnapshot? = null) {
        createChannel(context)
        val snap = snapshot ?: readSnapshot(context)
        val notification = buildHydrationNotification(
            context = context,
            notificationId = notificationId,
            titleOverride = "Hydration goal complete",
            bodyOverride = "You reached your water goal for today.",
            snapshot = snap,
            goalComplete = true,
        )
        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    fun cancel(context: Context, notificationId: Int) {
        NotificationManagerCompat.from(context).cancel(notificationId)
    }

    // ------------------------------------------------------------------
    // Scheduling
    // ------------------------------------------------------------------

    /**
     * Arms the next reminder. Reminders are a chain of one-shot alarms that
     * re-arm themselves in [WaterReminderAlarmReceiver], not a single
     * setInexactRepeating alarm: a repeating alarm that the OS drops (force
     * stop, standby-bucket demotion, OEM task killers) never comes back, and it
     * is deferred to Doze maintenance windows that can be hours apart.
     *
     * `setAndAllowWhileIdle` fires during Doze and needs no exact-alarm
     * permission. It is inexact — see the tolerance note in the docs.
     */
    fun scheduleRepeating(context: Context, intervalMinutes: Int) {
        cancelSchedule(context)
        persistInterval(context, intervalMinutes)
        if (intervalMinutes <= 0) return
        armNext(context, intervalMinutes)
    }

    /** Re-arm from the receiver after a reminder fires. */
    fun armNextFromReceiver(context: Context) {
        val minutes = storedIntervalMinutes(context)
        if (minutes > 0) armNext(context, minutes)
    }

    private fun armNext(context: Context, intervalMinutes: Int) {
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = alarmPendingIntent(context)
        val intervalMs = intervalMinutes.toLong() * 60_000L
        val triggerAt = System.currentTimeMillis() + intervalMs

        // FLAG_UPDATE_CURRENT reuses one PendingIntent, so re-arming replaces
        // the pending alarm instead of stacking a second one.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent,
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_NEXT_TRIGGER_AT, triggerAt)
            .apply()
    }

    fun cancelSchedule(context: Context) {
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(alarmPendingIntent(context))
        cancel(context, REMINDER_NOTIFICATION_ID)
        persistInterval(context, 0)
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_NEXT_TRIGGER_AT)
            .apply()
    }

    fun rescheduleAfterBoot(context: Context) {
        val minutes = storedIntervalMinutes(context)
        if (minutes > 0) {
            scheduleRepeating(context, minutes)
        }
    }

    /**
     * Re-arm only if reminders are enabled and nothing is pending — used on app
     * resume to heal a chain the OS dropped, without creating duplicates.
     */
    fun ensureScheduled(context: Context) {
        val minutes = storedIntervalMinutes(context)
        if (minutes <= 0) return
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val nextAt = prefs.getLong(KEY_NEXT_TRIGGER_AT, 0L)
        val overdue = nextAt <= 0L || nextAt < System.currentTimeMillis()
        if (overdue) armNext(context, minutes)
    }

    fun storedIntervalMinutes(context: Context): Int =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getInt(KEY_INTERVAL_MINUTES, 0)

    private fun alarmPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, WaterReminderAlarmReceiver::class.java).apply {
            action = ACTION_ALARM
        }
        return pendingBroadcast(context, REMINDER_NOTIFICATION_ID, intent)
    }

    private fun persistInterval(context: Context, intervalMinutes: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putInt(KEY_INTERVAL_MINUTES, intervalMinutes.coerceAtLeast(0))
            .apply()
    }

    private fun buildHydrationNotification(
        context: Context,
        notificationId: Int,
        titleOverride: String?,
        bodyOverride: String?,
        snapshot: HydrationSnapshot,
        goalComplete: Boolean,
    ): android.app.Notification {
        val title = titleOverride?.takeIf { it.isNotBlank() } ?: "Hydration check"
        val collapsedBody = bodyOverride?.takeIf { it.isNotBlank() }
            ?: if (goalComplete) {
                "You reached your water goal for today."
            } else if (snapshot.hasProgress) {
                "${formatMl(snapshot.consumedMl)} / ${formatMl(snapshot.goalMl)}"
            } else {
                "Time for some water"
            }

        val expanded = when {
            goalComplete -> collapsedBody
            snapshot.hasProgress -> {
                val remaining = (snapshot.goalMl - snapshot.consumedMl).coerceAtLeast(0)
                "You have ${formatMl(remaining)} left to reach today’s goal. Log a quick drink below."
            }
            else -> "Log your hydration in Cotrainr."
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_water)
            .setColor(ACCENT_ORANGE)
            .setContentTitle(title)
            .setContentText(collapsedBody)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(expanded)
                    .setBigContentTitle(title)
                    .setSummaryText("Cotrainr"),
            )
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentPendingIntent(context))
            .setDeleteIntent(null)

        BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher)?.let {
            builder.setLargeIcon(it)
        }

        if (!goalComplete && snapshot.hasProgress) {
            builder.setProgress(
                snapshot.goalMl,
                snapshot.consumedMl.coerceIn(0, snapshot.goalMl),
                false,
            )
            builder.setSubText(
                "${formatMl(snapshot.consumedMl)} / ${formatMl(snapshot.goalMl)}",
            )
        }

        if (!goalComplete) {
            builder.addAction(
                NotificationCompat.Action.Builder(
                    R.drawable.ic_notification_water,
                    "+250 ml",
                    actionPendingIntent(context, ACTION_ADD_250, notificationId * 16),
                ).build(),
            )
            builder.addAction(
                NotificationCompat.Action.Builder(
                    R.drawable.ic_notification_water,
                    "+500 ml",
                    actionPendingIntent(context, ACTION_ADD_500, notificationId * 16 + 1),
                ).build(),
            )
        }

        return builder.build()
    }

    private fun contentPendingIntent(context: Context): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("cotrainr://insights/water")).apply {
            setClass(context, MainActivity::class.java)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getActivity(context, 8801, intent, flags)
    }

    /**
     * Broadcast, never Activity: the quick-log actions must not open Cotrainr.
     * The amount is derived from the action string inside the receiver, so a
     * forged intent cannot inject an arbitrary value.
     */
    private fun actionPendingIntent(
        context: Context,
        actionId: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, WaterActionReceiver::class.java).apply {
            action = WaterActionReceiver.ACTION_QUICK_LOG
            putExtra(WaterActionReceiver.EXTRA_ACTION_ID, actionId)
        }
        return pendingBroadcast(context, requestCode, intent)
    }

    private fun pendingBroadcast(
        context: Context,
        requestCode: Int,
        intent: Intent,
    ): PendingIntent {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun readSnapshot(context: Context): HydrationSnapshot {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var consumed = prefs.getInt(KEY_CONSUMED_ML, -1)
        var goal = prefs.getInt(KEY_GOAL_ML, -1)
        var storedDate = prefs.getString(KEY_SNAPSHOT_DATE, null)

        // Fallback: Flutter SharedPreferences written from the Dart isolate.
        if (consumed < 0 || goal <= 0) {
            val flutterPrefs =
                context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (consumed < 0 && flutterPrefs.contains("flutter.hydration_notif_consumed_ml")) {
                consumed = flutterPrefs.getLong("flutter.hydration_notif_consumed_ml", -1L).toInt()
            }
            if (goal <= 0 && flutterPrefs.contains("flutter.hydration_notif_goal_ml")) {
                goal = flutterPrefs.getLong("flutter.hydration_notif_goal_ml", -1L).toInt()
            }
            if (storedDate == null) {
                storedDate = flutterPrefs.getString("flutter.hydration_local_date", null)
            }
        }

        // A snapshot from an earlier local day describes yesterday's progress.
        // Treating it as current used to let a completed goal suppress every
        // reminder on the following day.
        val isToday = storedDate != null && storedDate == localDateKey()
        val consumedToday = if (isToday) consumed.coerceAtLeast(0) else 0

        return HydrationSnapshot(
            consumedMl = consumedToday,
            goalMl = goal,
            isFresh = goal > 0,
        )
    }

    private fun formatMl(ml: Int): String {
        return "%,d ml".format(ml)
    }

    data class HydrationSnapshot(
        val consumedMl: Int,
        val goalMl: Int,
        val isFresh: Boolean,
    ) {
        val hasProgress: Boolean
            get() = isFresh && goalMl > 0 && consumedMl >= 0

        val goalReached: Boolean
            get() = hasProgress && consumedMl >= goalMl
    }
}
