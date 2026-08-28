package com.cotrainr.app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity required for Health Connect permission flow on Android 14+
// (registerForActivityResult needs ComponentActivity)
class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "cotrainr/water_notifications"

        /**
         * Set while a Flutter engine is attached. The quick-log receiver uses
         * this to nudge a live UI into reconciling immediately; when it is null
         * the event simply waits on disk for the next app start.
         */
        @Volatile
        private var attachedWaterChannel: MethodChannel? = null

        fun notifyQuickLogIfAttached(actionId: String) {
            val channel = attachedWaterChannel ?: return
            Handler(Looper.getMainLooper()).post {
                try {
                    channel.invokeMethod(
                        "onWaterQuickLogApplied",
                        mapOf("actionId" to actionId),
                    )
                } catch (_: Throwable) {
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WaterNotificationHelper.createChannel(this)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "showWaterReminder" -> {
                    val id = call.argument<Int>("notificationId")
                        ?: WaterNotificationHelper.REMINDER_NOTIFICATION_ID
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val goalComplete = call.argument<Boolean>("goalComplete") ?: false
                    if (goalComplete) {
                        WaterNotificationHelper.showGoalComplete(this, id)
                    } else {
                        WaterNotificationHelper.show(this, id, title, body)
                    }
                    result.success(true)
                }
                "scheduleWaterReminder" -> {
                    val minutes = call.argument<Int>("intervalMinutes") ?: 0
                    WaterNotificationHelper.scheduleRepeating(this, minutes)
                    result.success(true)
                }
                "cancelWaterReminder" -> {
                    WaterNotificationHelper.cancelSchedule(this)
                    result.success(true)
                }
                "ensureWaterSchedule" -> {
                    WaterNotificationHelper.ensureScheduled(this)
                    result.success(WaterNotificationHelper.storedIntervalMinutes(this))
                }
                "syncHydrationSnapshot" -> {
                    val consumedMl = call.argument<Int>("consumedMl") ?: -1
                    val goalMl = call.argument<Int>("goalMl") ?: -1
                    WaterNotificationHelper.syncHydrationSnapshot(this, consumedMl, goalMl)
                    result.success(true)
                }
                "drainPendingQuickLogs" -> {
                    result.success(WaterNotificationHelper.drainPendingQuickLogs(this))
                }
                "clearPendingQuickLogs" -> {
                    val ids = call.argument<List<String>>("eventIds") ?: emptyList()
                    WaterNotificationHelper.clearPendingQuickLogs(this, ids)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        attachedWaterChannel = channel
    }

    override fun onDestroy() {
        attachedWaterChannel = null
        super.onDestroy()
    }
}
