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
            else -> {
                // Re-arm first: reminders are a chain of one-shot alarms, so
                // the chain must continue even if posting the notification
                // throws (channel blocked, notifications revoked, OOM).
                WaterNotificationHelper.armNextFromReceiver(context)
                try {
                    WaterNotificationHelper.showScheduledReminder(context)
                } catch (_: Throwable) {
                }
            }
        }
    }
}
