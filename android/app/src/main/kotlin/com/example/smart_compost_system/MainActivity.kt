package com.example.smart_compost_system

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.smart_compost_system/notifications"
    private lateinit var notificationHelper: CompostNotificationHelper

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationHelper = CompostNotificationHelper(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "show5DayMilestone" -> {
                    val pileName = call.argument<String>("pileName") ?: "Compost Pile"
                    notificationHelper.show5DayMilestoneNotification(pileName)
                    result.success(true)
                }
                "showCompletion" -> {
                    val pileName = call.argument<String>("pileName") ?: "Compost Pile"
                    notificationHelper.showCompletionNotification(pileName)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
