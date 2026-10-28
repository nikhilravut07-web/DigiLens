package com.example.digilens

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "DigiLensSmsReceiver"
        private var smsEventListener: ((String, String, Long) -> Unit)? = null

        fun setSmsEventListener(listener: (String, String, Long) -> Unit) {
            smsEventListener = listener
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            try {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (messages != null && messages.isNotEmpty()) {
                    val sender = messages[0].originatingAddress ?: "Unknown"
                    val timestamp = messages[0].timestampMillis

                    // Assemble multipart SMS messages
                    val sb = StringBuilder()
                    for (msg in messages) {
                        sb.append(msg.messageBody ?: "")
                    }
                    val body = sb.toString()

                    // Sanitize log: Never log full sender phone number or SMS message contents to system logs
                    Log.i(TAG, "Incoming SMS intercepted (length=${body.length}) for security evaluation")

                    // Notify listener if registered (Flutter background/foreground service)
                    smsEventListener?.invoke(sender, body, timestamp)

                    // Also dispatch to Notification Helper to display threat warning if suspicious
                    DigiLensNotificationHelper.showSmsNotification(context, sender, body, timestamp)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to process incoming SMS PDU", e)
            }
        }
    }
}
