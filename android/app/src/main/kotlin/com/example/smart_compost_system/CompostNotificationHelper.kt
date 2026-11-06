package com.example.smart_compost_system

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class CompostNotificationHelper(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "compost_milestones_channel"
        const val CHANNEL_NAME = "Compost Wise Milestones"
        const val CHANNEL_DESC = "Notifications for compost 5-day milestones and pile readiness completion"
    }

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = CHANNEL_DESC
            }
            val notificationManager: NotificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun show5DayMilestoneNotification(pileName: String) {
        showNotification(
            id = 1001,
            title = "Compost Milestone Update",
            message = "Compost Update: $pileName has reached 5 days!"
        )
    }

    fun showCompletionNotification(pileName: String) {
        showNotification(
            id = 1002,
            title = "Compost Ready!",
            message = "Compost Ready! $pileName is ready for use"
        )
    }

    private fun showNotification(id: Int, title: String, message: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ActivityCompat.checkSelfPermission(
                    context,
                    android.Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        try {
            with(NotificationManagerCompat.from(context)) {
                notify(id, builder.build())
            }
        } catch (_) {}
    }
}
