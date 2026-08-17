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

    private const val ACTION_ALARM = "com.cotrainr.app.WATER_REMINDER_ALARM"
    private const val ACTION_BROADCAST_TAPPED =
        "com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver.ACTION_TAPPED"

    private const val PREFS_NAME = "cotrainr_hydration"
    private const val KEY_CONSUMED_ML = "consumed_ml"
    private const val KEY_GOAL_ML = "goal_ml"
    private const val KEY_UPDATED_AT = "updated_at_ms"

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

    fun syncHydrationSnapshot(context: Context, consumedMl: Int, goalMl: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putInt(KEY_CONSUMED_ML, consumedMl.coerceAtLeast(0))
            .putInt(KEY_GOAL_ML, goalMl.coerceAtLeast(0))
            .putLong(KEY_UPDATED_AT, System.currentTimeMillis())
            .apply()
    }

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

    fun scheduleRepeating(context: Context, intervalMinutes: Int) {
        cancelSchedule(context)
        if (intervalMinutes <= 0) return

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, WaterReminderAlarmReceiver::class.java).apply {
            action = ACTION_ALARM
        }
        val pendingIntent = pendingBroadcast(
            context,
            REMINDER_NOTIFICATION_ID,
            intent,
        )
        val intervalMs = intervalMinutes.toLong() * 60_000L
        val triggerAt = System.currentTimeMillis() + intervalMs

        alarmManager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            intervalMs,
            pendingIntent,
        )
    }

    fun cancelSchedule(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, WaterReminderAlarmReceiver::class.java).apply {
            action = ACTION_ALARM
        }
        val pendingIntent = pendingBroadcast(
            context,
            REMINDER_NOTIFICATION_ID,
            intent,
        )
        alarmManager.cancel(pendingIntent)
        cancel(context, REMINDER_NOTIFICATION_ID)
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
            } else {
                "Time for some water"
            }

        val expanded = when {
            goalComplete -> collapsedBody
            snapshot.hasProgress -> {
                val remaining = (snapshot.goalMl - snapshot.consumedMl).coerceAtLeast(0)
                "You have ${formatMl(remaining)} left to reach today’s goal. Log a quick drink below."
            }
            else -> "Stay on track with your daily goal. Log a quick drink below."
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
                    actionPendingIntent(context, notificationId, ACTION_ADD_250, notificationId * 16),
                ).build(),
            )
            builder.addAction(
                NotificationCompat.Action.Builder(
                    R.drawable.ic_notification_water,
                    "+500 ml",
                    actionPendingIntent(
                        context,
                        notificationId,
                        ACTION_ADD_500,
                        notificationId * 16 + 1,
                    ),
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

    private fun actionPendingIntent(
        context: Context,
        notificationId: Int,
        actionId: String,
        requestCode: Int,
    ): PendingIntent {
        // Route through MainActivity so logging runs on the main Flutter isolate
        // (same WaterIntakeService / ValueNotifier the UI listens to).
        val intent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_WATER_QUICK_LOG
            putExtra("actionId", actionId)
            putExtra("notificationId", notificationId)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getActivity(context, requestCode, intent, flags)
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
        var updatedAt = prefs.getLong(KEY_UPDATED_AT, 0L)

        // Fallback: Flutter SharedPreferences written from Dart background isolate.
        if (consumed < 0 || goal <= 0) {
            val flutterPrefs =
                context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (consumed < 0 && flutterPrefs.contains("flutter.hydration_notif_consumed_ml")) {
                consumed = flutterPrefs.getLong("flutter.hydration_notif_consumed_ml", -1L).toInt()
            }
            if (goal <= 0 && flutterPrefs.contains("flutter.hydration_notif_goal_ml")) {
                goal = flutterPrefs.getLong("flutter.hydration_notif_goal_ml", -1L).toInt()
            }
            if (updatedAt <= 0L && flutterPrefs.contains("flutter.hydration_notif_updated_at_ms")) {
                updatedAt = flutterPrefs.getLong("flutter.hydration_notif_updated_at_ms", 0L)
            }
        }

        val fresh = updatedAt > 0L &&
            (System.currentTimeMillis() - updatedAt) < 36L * 60L * 60L * 1000L
        return HydrationSnapshot(
            consumedMl = consumed,
            goalMl = goal,
            isFresh = fresh || (consumed >= 0 && goal > 0),
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
