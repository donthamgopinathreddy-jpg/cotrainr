package com.cotrainr.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Handles the +250 ml / +500 ml notification actions.
 *
 * A BroadcastReceiver, not an Activity: tapping an action must never open
 * Cotrainr. The work runs in the app process without a Flutter engine, so it
 * also works when the UI has been swiped away or was never started.
 *
 * Declared `exported="false"`, and the amount is looked up from a fixed
 * allow-list keyed by the action id rather than read from an extra, so a forged
 * intent cannot log an arbitrary amount.
 */
class WaterActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_QUICK_LOG = "com.cotrainr.app.WATER_QUICK_LOG_ACTION"
        const val EXTRA_ACTION_ID = "actionId"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_QUICK_LOG) return
        val actionId = intent.getStringExtra(EXTRA_ACTION_ID) ?: return
        if (WaterNotificationHelper.amountForAction(actionId) == null) return

        // goAsync keeps the receiver alive past onReceive for the disk commit.
        val pending = goAsync()
        Thread {
            try {
                val applied = WaterNotificationHelper.applyQuickLog(context, actionId)
                if (applied != null) {
                    WaterNotificationHelper.refreshAfterQuickLog(context)
                    // If the UI happens to be running, let it reconcile now
                    // instead of waiting for the next resume.
                    MainActivity.notifyQuickLogIfAttached(actionId)
                }
            } catch (_: Throwable) {
                // Never crash the receiver — the event is already on disk if the
                // commit succeeded, and Dart reconciles on next launch.
            } finally {
                pending.finish()
            }
        }.start()
    }
}
