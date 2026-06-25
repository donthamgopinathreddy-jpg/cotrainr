package com.example.cotrainr

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WaterReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        WaterNotificationHelper.show(
            context,
            WaterNotificationHelper.REMINDER_NOTIFICATION_ID,
            "Time to drink water 💧",
            "Tap a preset to add water.",
        )
    }
}
