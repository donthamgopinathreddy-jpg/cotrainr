package com.cotrainr.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity required for Health Connect permission flow on Android 14+
// (registerForActivityResult needs ComponentActivity)
class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val ACTION_WATER_QUICK_LOG = "com.cotrainr.app.WATER_QUICK_LOG"
        private const val CHANNEL = "cotrainr/water_notifications"
    }

    private var waterChannel: MethodChannel? = null
    private var pendingWaterActionId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureWaterAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureWaterAction(intent)
        deliverPendingWaterAction()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WaterNotificationHelper.createChannel(this)
        waterChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).also { channel ->
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
                    "syncHydrationSnapshot" -> {
                        val consumedMl = call.argument<Int>("consumedMl") ?: -1
                        val goalMl = call.argument<Int>("goalMl") ?: -1
                        WaterNotificationHelper.syncHydrationSnapshot(this, consumedMl, goalMl)
                        result.success(true)
                    }
                    "readyForWaterActions" -> {
                        // Dart handler is attached — safe to deliver.
                        deliverPendingWaterAction()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        // Do not deliver here: Dart MethodChannel handler may not be set yet.
        // Delivery happens when Flutter calls readyForWaterActions.
    }

    private fun captureWaterAction(intent: Intent?) {
        if (intent?.action != ACTION_WATER_QUICK_LOG) return
        pendingWaterActionId = intent.getStringExtra("actionId")
    }

    private fun deliverPendingWaterAction() {
        val actionId = pendingWaterActionId ?: return
        val channel = waterChannel ?: return
        // Keep pending until Dart acknowledges — otherwise cold-start races
        // drop the action before the Flutter handler is attached.
        channel.invokeMethod(
            "onWaterQuickLog",
            mapOf("actionId" to actionId),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    pendingWaterActionId = null
                }

                override fun error(
                    errorCode: String,
                    errorMessage: String?,
                    errorDetails: Any?,
                ) {
                    // Keep pending for a later readyForWaterActions retry.
                }

                override fun notImplemented() {
                    // Keep pending for a later readyForWaterActions retry.
                }
            },
        )
    }
}
