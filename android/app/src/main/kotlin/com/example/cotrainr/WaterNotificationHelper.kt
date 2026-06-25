package com.example.cotrainr

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.cotrainr.R

object WaterNotificationHelper {
    const val CHANNEL_ID = "water_reminders"
    const val CHANNEL_NAME = "Water Reminders"
    const val REMINDER_NOTIFICATION_ID = 9100
    const val TEST_NOTIFICATION_ID = 9099

    const val ACTION_ADD_250 = "water_add_250"
    const val ACTION_ADD_500 = "water_add_500"

    private const val ACTION_ALARM = "com.example.cotrainr.WATER_REMINDER_ALARM"
    private const val ACTION_BROADCAST_TAPPED =
        "com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver.ACTION_TAPPED"

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Periodic reminders to log water intake"
        }
        manager.createNotificationChannel(channel)
    }

    fun show(context: Context, notificationId: Int, title: String, body: String) {
        createChannel(context)
        val notification = buildPillNotification(context, notificationId, title, body)
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

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                intervalMs,
                pendingIntent,
            )
        } else {
            alarmManager.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                intervalMs,
                pendingIntent,
            )
        }
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

    fun buildPillNotification(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
    ): android.app.Notification {
        val remoteViews = android.widget.RemoteViews(
            context.packageName,
            R.layout.water_reminder_notification,
        )
        remoteViews.setTextViewText(R.id.water_notification_title, title)
        remoteViews.setTextViewText(R.id.water_notification_body, body)

        bindPill(
            context,
            remoteViews,
            R.id.water_pill_250,
            ACTION_ADD_250,
            notificationId,
            notificationId * 16,
        )
        bindPill(
            context,
            remoteViews,
            R.id.water_pill_500,
            ACTION_ADD_500,
            notificationId,
            notificationId * 16 + 1,
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
    }

    private fun bindPill(
        context: Context,
        remoteViews: android.widget.RemoteViews,
        viewId: Int,
        actionId: String,
        notificationId: Int,
        requestCode: Int,
    ) {
        remoteViews.setOnClickPendingIntent(
            viewId,
            pillActionPendingIntent(context, notificationId, actionId, requestCode),
        )
    }

    private fun pillActionPendingIntent(
        context: Context,
        notificationId: Int,
        actionId: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent().apply {
            setClassName(
                context,
                "com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver",
            )
            action = ACTION_BROADCAST_TAPPED
            putExtra("notificationId", notificationId)
            putExtra("actionId", actionId)
            putExtra("cancelNotification", true)
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
}
