package com.example.digilens

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

object DigiLensNotificationHelper {
    private const val CHANNEL_ID = "digilens_sms_threats"
    private const val CHANNEL_NAME = "DigiLens SMS Threat Alerts"
    private const val NOTIFICATION_ID_BASE = 2000

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when incoming SMS messages contain smishing or financial fraud indicators"
                enableVibration(true)
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun maskSender(sender: String): String {
        val digitsOnly = sender.filter { it.isDigit() }
        return if (digitsOnly.length >= 10) {
            val prefix = if (sender.startsWith("+")) sender.take(3) + " " else ""
            val rest = digitsOnly.takeLast(10)
            prefix + rest.take(2) + "******" + rest.takeLast(2)
        } else {
            sender
        }
    }

    fun showSmsNotification(
        context: Context,
        sender: String,
        body: String,
        timestamp: Long = System.currentTimeMillis()
    ) {
        createNotificationChannel(context)

        // Simple heuristic check for notification gating
        val lower = body.lowercase()
        val isSuspicious = lower.contains("otp") ||
                lower.contains("kyc") ||
                lower.contains("blocked") ||
                lower.contains("suspended") ||
                lower.contains("urgent") ||
                lower.contains("click") ||
                lower.contains("won") ||
                lower.contains("loan") ||
                lower.contains("cbi") ||
                lower.contains("arrest") ||
                lower.contains("http") ||
                lower.contains("www.")

        if (!isSuspicious) {
            // Do not spam notifications for completely normal SMS
            return
        }

        // Generate distinct notification ID and request code per unique threat
        val notificationId = NOTIFICATION_ID_BASE + ((sender.hashCode() xor body.hashCode()) and 0x7FFFFFFF) % 10000

        val intent = Intent(context, MainActivity::class.java).apply {
            action = "com.example.digilens.ACTION_SMS_NOTIFICATION_$notificationId"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("incoming_sms_body", body)
            putExtra("incoming_sms_sender", sender)
            putExtra("incoming_sms_timestamp", timestamp)
            putExtra("from_notification", true)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val riskTitle = if (lower.contains("cbi") || lower.contains("arrest")) {
            "🚨 Critical Scam SMS Alert: Extortion Risk"
        } else if (lower.contains("otp") || lower.contains("kyc") || lower.contains("blocked")) {
            "⚠️ Suspicious Smishing SMS Detected"
        } else {
            "⚠️ Potential Scam SMS Detected"
        }

        val maskedSender = maskSender(sender)
        val maskedBodyPreview = if (body.length > 60) "${body.take(60)}..." else body

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(riskTitle)
            .setContentText("From $maskedSender: $maskedBodyPreview")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("Sender: $maskedSender\n\n$body\n\n⚠️ Tap to inspect risk details, indicators, and recommended safety actions.")
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, notification)
    }
}
