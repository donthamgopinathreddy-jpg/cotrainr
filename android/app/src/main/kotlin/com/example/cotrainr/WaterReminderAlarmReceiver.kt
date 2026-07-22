package com.example.cotrainr

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WaterReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        WaterNotificationHelper.showScheduledReminder(context)
    }
}
