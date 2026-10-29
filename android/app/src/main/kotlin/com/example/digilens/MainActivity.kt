package com.example.digilens

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.digilens/browser"
    private val SMS_CHANNEL = "com.example.digilens/sms_guard"
    private var methodChannel: MethodChannel? = null
    private var smsMethodChannel: MethodChannel? = null
    private var pendingIntentUrl: String? = null
    private var pendingIntentSource: String? = null
    private var pendingSmsPayload: Map<String, String>? = null

    // Track the last intent identity to avoid re-processing the same intent
    // on configuration changes or when onNewIntent delivers the same object.
    private var lastProcessedIntentId: Long = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        setupSmsReceiverListener()
    }

    private fun setupSmsReceiverListener() {
        SmsReceiver.setSmsEventListener { sender, body, timestamp ->
            runOnUiThread {
                val payload = mapOf(
                    "sender" to sender,
                    "body" to body,
                    "timestamp" to timestamp.toString()
                )
                if (smsMethodChannel != null) {
                    smsMethodChannel?.invokeMethod("onIncomingSms", payload)
                } else {
                    pendingSmsPayload = payload
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun resolveSourceApp(intent: Intent?): String {
        var rawReferrer: String? = null
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
                val refUri = referrer
                if (refUri != null) {
                    rawReferrer = refUri.toString()
                }
            }
        } catch (_: Exception) {}

        if (rawReferrer.isNullOrEmpty() && intent != null) {
            val extraRef = intent.getParcelableExtra<Uri>(Intent.EXTRA_REFERRER)
            if (extraRef != null) {
                rawReferrer = extraRef.toString()
            } else {
                rawReferrer = intent.getStringExtra(Intent.EXTRA_REFERRER_NAME)
            }
        }

        if (rawReferrer.isNullOrEmpty() && callingPackage != null) {
            rawReferrer = "android-app://$callingPackage"
        }

        if (rawReferrer != null) {
            val lower = rawReferrer.lowercase()
            return when {
                lower.contains("whatsapp") -> "WhatsApp"
                lower.contains("messaging") || lower.contains("mms") || lower.contains("sms") -> "SMS"
                lower.contains("telegram") -> "Telegram"
                lower.contains("chrome") || lower.contains("firefox") || lower.contains("browser") -> "Browser"
                lower.startsWith("android-app://") -> {
                    val pkg = lower.removePrefix("android-app://")
                    val seg = pkg.split('.').lastOrNull()
                    if (!seg.isNullOrBlank()) {
                        seg.replaceFirstChar { it.uppercase() }
                    } else "External App"
                }
                else -> "External App"
            }
        }
        return "External App"
    }

    private fun extractUrlFromText(text: String?): String? {
        if (text.isNullOrBlank()) return null
        val urlRegex = Regex("""https?://[^\s<>"]+""", RegexOption.IGNORE_CASE)
        return urlRegex.find(text)?.value
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val data = intent.data

        if (intent.hasExtra("incoming_sms_body")) {
            val body = intent.getStringExtra("incoming_sms_body") ?: ""
            val sender = intent.getStringExtra("incoming_sms_sender") ?: "Unknown"
            val timestamp = intent.getLongExtra("incoming_sms_timestamp", System.currentTimeMillis())
            val intentIdentity = (sender + body + timestamp).hashCode().toLong()
            if (intentIdentity == lastProcessedIntentId) return
            lastProcessedIntentId = intentIdentity

            val payload = mapOf(
                "sender" to sender,
                "body" to body,
                "timestamp" to timestamp.toString(),
                "fromNotification" to "true"
            )
            if (smsMethodChannel != null) {
                smsMethodChannel?.invokeMethod("onSmsNotificationTapped", payload)
            } else {
                pendingSmsPayload = payload
            }
        }

        if (Intent.ACTION_VIEW == action && data != null) {
            // Use a synthetic identity based on dataString + timestamp to
            // deduplicate the same intent delivered twice (configuration
            // changes, singleTop re-delivery, etc.).
            val intentIdentity = (data.toString() + intent.getLongExtra("_ts", 0L)).hashCode().toLong()
            if (intentIdentity == lastProcessedIntentId) return
            lastProcessedIntentId = intentIdentity

            val scheme = data.scheme?.lowercase() ?: ""
            // Only accept HTTP/HTTPS URLs at the native layer. Any other
            // scheme that somehow arrives via the intent filter is dropped
            // here so it never reaches Flutter or the WebView.
            if (scheme != "http" && scheme != "https") return

            val url = data.toString()
            val sourceApp = resolveSourceApp(intent)
            val payload = mapOf("url" to url, "source" to sourceApp)
            if (methodChannel != null) {
                methodChannel?.invokeMethod("onIncomingUrl", payload)
            } else {
                pendingIntentUrl = url
                pendingIntentSource = sourceApp
            }
        } else if (Intent.ACTION_SEND == action && intent.type?.startsWith("text/") == true) {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
            val extractedUrl = extractUrlFromText(sharedText)
            if (extractedUrl != null) {
                val intentIdentity = (extractedUrl + intent.getLongExtra("_ts", 0L)).hashCode().toLong()
                if (intentIdentity == lastProcessedIntentId) return
                lastProcessedIntentId = intentIdentity

                val sourceApp = resolveSourceApp(intent)
                val payload = mapOf("url" to extractedUrl, "source" to sourceApp)
                if (methodChannel != null) {
                    methodChannel?.invokeMethod("onIncomingUrl", payload)
                } else {
                    pendingIntentUrl = extractedUrl
                    pendingIntentSource = sourceApp
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openBrowser" -> {
                    val url = call.argument<String>("url")
                    val scanResult = call.argument<Map<String, Any>>("scanResult")
                    val riskLevel = scanResult?.get("riskLevel") as? String ?: "safe"

                    if (url != null) {
                        val intent = Intent(this, ProtectedBrowserActivity::class.java).apply {
                            putExtra("target_url", url)
                            putExtra("risk_level", riskLevel)
                        }
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "URL is null", null)
                    }
                }
                "getInitialIntent" -> {
                    val url = pendingIntentUrl
                    val source = pendingIntentSource
                    pendingIntentUrl = null
                    pendingIntentSource = null
                    if (url != null) {
                        result.success(mapOf("url" to url, "source" to (source ?: "External App")))
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // If there was a pending URL from cold start, notify Flutter once channel is ready
        pendingIntentUrl?.let { url ->
            val source = pendingIntentSource ?: "External App"
            channel.invokeMethod("onIncomingUrl", mapOf("url" to url, "source" to source))
            pendingIntentUrl = null
            pendingIntentSource = null
        }

        // Setup SMS Guard Method Channel
        val smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsMethodChannel = smsChannel

        smsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingSms" -> {
                    val payload = pendingSmsPayload
                    pendingSmsPayload = null
                    result.success(payload)
                }
                "checkSmsServiceStatus" -> {
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        pendingSmsPayload?.let { payload ->
            smsChannel.invokeMethod("onIncomingSms", payload)
            pendingSmsPayload = null
        }
    }
}
