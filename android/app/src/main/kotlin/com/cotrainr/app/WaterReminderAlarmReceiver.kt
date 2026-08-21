package com.cotrainr.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WaterReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                WaterNotificationHelper.rescheduleAfterBoot(context)
            }
            else -> WaterNotificationHelper.showScheduledReminder(context)
        }
    }
}
