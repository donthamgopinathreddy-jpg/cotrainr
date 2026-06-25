package com.example.cotrainr

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity required for Health Connect permission flow on Android 14+
// (registerForActivityResult needs ComponentActivity)
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WaterNotificationHelper.createChannel(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cotrainr/water_notifications",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showWaterReminder" -> {
                    val id = call.argument<Int>("notificationId")
                        ?: WaterNotificationHelper.REMINDER_NOTIFICATION_ID
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    WaterNotificationHelper.show(this, id, title, body)
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
                else -> result.notImplemented()
            }
        }
    }
}
