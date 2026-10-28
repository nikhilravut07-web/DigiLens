package com.example.digilens

import android.annotation.SuppressLint
import android.app.Activity
import android.graphics.Bitmap
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.webkit.SafeBrowsingResponse
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.net.http.SslError

class ProtectedBrowserActivity : Activity() {

    private lateinit var webView: WebView
    private lateinit var progressBar: ProgressBar
    private lateinit var urlTextView: TextView
    private lateinit var hostTextView: TextView
    private lateinit var riskBadgeTextView: TextView
    private lateinit var warningBanner: LinearLayout
    private lateinit var warningTitleView: TextView
    private lateinit var warningDescView: TextView
    private lateinit var backToSafetyButton: Button
    private lateinit var backButton: TextView

    private var currentUrl: String = ""

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_protected_browser)

        backButton = findViewById(R.id.backButton)
        backButton.setOnClickListener { finish() }

        webView = findViewById(R.id.webView)
        progressBar = findViewById(R.id.progressBar)
        urlTextView = findViewById(R.id.urlTextView)
        hostTextView = findViewById(R.id.hostTextView)
        riskBadgeTextView = findViewById(R.id.riskBadgeTextView)
        warningBanner = findViewById(R.id.warningBanner)
        warningTitleView = findViewById(R.id.warningTitleView)
        warningDescView = findViewById(R.id.warningDescView)
        backToSafetyButton = findViewById(R.id.backToSafetyButton)

        backToSafetyButton.setOnClickListener { finish() }

        // Configure secure WebView settings per DigiLens security guidelines
        val settings = webView.settings
        settings.javaScriptEnabled = true
        settings.allowFileAccess = false
        settings.allowContentAccess = false
        @Suppress("DEPRECATION")
        settings.allowUniversalAccessFromFileURLs = false
        @Suppress("DEPRECATION")
        settings.allowFileAccessFromFileURLs = false
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        settings.domStorageEnabled = true
        settings.databaseEnabled = false

        // Enable Android WebView Safe Browsing where supported (API 27+).
        // On API 27 (O_MR1) the setting exists but Google Play Services
        // must be up-to-date; on API 28+ it is enabled by default but we
        // set it explicitly to ensure it is never turned off.
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            settings.safeBrowsingEnabled = true
        }

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url?.toString() ?: return true
                return !inspectAndAuthorizeNavigation(url)
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                progressBar.visibility = View.VISIBLE
                if (url != null) {
                    updateAddressBar(url)
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                progressBar.visibility = View.GONE
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                super.onReceivedError(view, request, error)
                progressBar.visibility = View.GONE
            }

            // ── SSL certificate errors: fail-closed ────────────────────────
            // Never bypass certificate errors. This prevents MITM attacks
            // even when the user has installed a rogue CA certificate.
            override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
                // Cancel the load (fail-closed) — never call handler.proceed().
                handler?.cancel()
                showBlockedState(
                    "SSL certificate error — connection refused for your safety. " +
                    "Reason: ${error?.primaryError ?: "unknown"}"
                )
            }

            // ── Safe Browsing threat detected (API 27+) ────────────────────
            // Return to safety instead of proceeding to the dangerous page.
            override fun onSafeBrowsingHit(
                view: WebView?,
                request: WebResourceRequest?,
                threatType: Int,
                callback: SafeBrowsingResponse?
            ) {
                // Show the interstitial warning provided by the system and
                // back away. Do NOT call callback.proceed() — that would
                // load the dangerous content.
                callback?.backToSafety(/* report = */ true)
                showBlockedState(
                    "Google Safe Browsing flagged this page (threat type $threatType). " +
                    "Navigation has been blocked for your protection."
                )
            }
        }

        val targetUrl = intent.getStringExtra("target_url") ?: "https://example.com"
        val riskLevel = intent.getStringExtra("risk_level") ?: "safe"

        updateAddressBar(targetUrl)
        updateRiskBadge(riskLevel)

        if (inspectAndAuthorizeNavigation(targetUrl)) {
            warningBanner.visibility = View.GONE
            webView.visibility = View.VISIBLE
            webView.loadUrl(targetUrl)
        } else {
            // Blocked by scheme or security check
            webView.visibility = View.GONE
            warningBanner.visibility = View.VISIBLE
            warningTitleView.text = "Navigation Blocked"
            warningDescView.text = "The URL uses an unsupported or dangerous scheme and has been blocked for your protection."
        }
    }

    private fun updateAddressBar(url: String) {
        urlTextView.text = url
        try {
            val uri = Uri.parse(url)
            hostTextView.text = uri.host ?: url
        } catch (e: Exception) {
            hostTextView.text = url
        }
    }

    private fun updateRiskBadge(riskLevel: String) {
        when (riskLevel.lowercase()) {
            "critical", "high" -> {
                riskBadgeTextView.text = "HIGH RISK"
                riskBadgeTextView.setTextColor(0xFFDC2626.toInt())
                riskBadgeTextView.setBackgroundResource(R.drawable.badge_background)
            }
            "medium" -> {
                riskBadgeTextView.text = "WARNING"
                riskBadgeTextView.setTextColor(0xFFD97706.toInt())
                riskBadgeTextView.setBackgroundResource(R.drawable.badge_background)
            }
            else -> {
                riskBadgeTextView.text = "PROTECTED"
                riskBadgeTextView.setTextColor(0xFF16A34A.toInt())
                riskBadgeTextView.setBackgroundResource(R.drawable.badge_background)
            }
        }
    }

    private fun inspectAndAuthorizeNavigation(url: String): Boolean {
        val lower = url.trim().lowercase()

        // Use proper URI parsing to validate schemes instead of only
        // string-prefix matching. This catches edge-cases like
        // "JAVASCRIPT:" or " javascript:" (after trim).
        val parsedUri = try {
            Uri.parse(url.trim())
        } catch (_: Exception) {
            showBlockedState("Malformed URL could not be parsed: $url")
            return false
        }

        val scheme = parsedUri.scheme?.lowercase() ?: ""

        // Reject dangerous and unhandled schemes
        val dangerousSchemes = setOf(
            "javascript", "data", "file", "content",
            "intent", "vbscript", "blob"
        )
        if (scheme in dangerousSchemes) {
            showBlockedState("Dangerous or unsupported URI scheme blocked: $url")
            return false
        }

        // Accept only http and https destinations
        if (scheme != "http" && scheme != "https") {
            showBlockedState("Unsupported URL scheme: $url")
            return false
        }

        currentUrl = url
        updateAddressBar(url)
        return true
    }

    private fun showBlockedState(reason: String) {
        webView.visibility = View.GONE
        warningBanner.visibility = View.VISIBLE
        warningTitleView.text = "Security Interception"
        warningDescView.text = reason
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
}
