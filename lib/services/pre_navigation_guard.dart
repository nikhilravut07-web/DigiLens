import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/theme/app_theme.dart';
import 'package:digilens/components/status_chip.dart';
import 'package:digilens/services/url_analysis_service.dart';
import 'package:digilens/screens/safe_browser_screen.dart';

// ─── Dangerous-scheme list ──────────────────────────────────────────────────
/// Schemes that must NEVER be passed to a browser or WebView for execution.
/// Visible for testing so that the exact same list governs both production
/// navigation decisions and unit-test assertions.
const Set<String> dangerousSchemes = {'javascript', 'data', 'vbscript', 'blob'};

/// Schemes that DigiLens allows through to the safe-browser viewer.
/// Everything not in [permittedSchemes] or [dangerousSchemes] falls through
/// to URL analysis where heuristic scoring decides.
const Set<String> permittedSchemes = {'http', 'https'};

// ─── Pure navigation-decision function ──────────────────────────────────────

/// Outcome of the pre-navigation scheme/risk check.
///
/// This is the *pure* decision layer — no UI, no context, no async beyond
/// the analysis call. Both production code and tests use this function so
/// the guard logic is always in sync.
enum NavigationDecision {
  /// The URL scheme is dangerous (javascript:, data:, etc.) — block outright.
  blocked,

  /// Heuristic analysis flagged the URL at medium risk or above — the caller
  /// should present a warning and let the user decide.
  warn,

  /// The URL appears safe — proceed to the in-app browser viewer.
  allow,
}

/// Decide what the navigation guard should do for [targetUrl] given its
/// [analysisResult].
///
/// This is a pure, synchronous function with no Flutter/UI dependency so it
/// can be unit-tested without `WidgetsFlutterBinding`.
NavigationDecision evaluateNavigation({
  required String targetUrl,
  required ScanResult analysisResult,
}) {
  // 1. Hard-block dangerous executable URI schemes.
  final lowerUrl = targetUrl.trim().toLowerCase();
  for (final scheme in dangerousSchemes) {
    if (lowerUrl.startsWith('$scheme:')) {
      return NavigationDecision.blocked;
    }
  }

  // 2. Non-HTTP schemes that are not in the dangerous list are allowed
  //    through to heuristic scoring — ftp://, tel://, mailto:, etc. fall here.

  // 3. Risk-based decision from heuristic analysis.
  final isRisky =
      analysisResult.riskLevel == RiskLevel.medium ||
      analysisResult.riskLevel == RiskLevel.high ||
      analysisResult.riskLevel == RiskLevel.critical;

  return isRisky ? NavigationDecision.warn : NavigationDecision.allow;
}

/// Service responsible for intercepting link navigation and warning users
/// before suspicious links are opened.
///
/// PLATFORM LIMITATION NOTE:
/// This guard protects navigation initiated WITHIN DigiLens (e.g. clicking
/// links in SMS analysis, link results, or in-app browser flows).
/// Android system-wide link interception across ALL 3rd-party apps requires
/// an Accessibility Service or VPN-based DNS proxy, which is not implemented
/// in this mobile prototype and requires explicit OS-level elevated permissions.
class PreNavigationGuard {
  static const MethodChannel browserChannel = MethodChannel(
    'com.example.digilens/browser',
  );
  static bool _intentHandlerInitialized = false;

  // ── Duplicate-intent guard ───────────────────────────────────────────────
  // Tracks URLs currently being analysed to prevent a second incoming intent
  // (e.g. the onIncomingUrl callback racing with getInitialIntent on cold
  // start) from spawning a second parallel analysis+navigation flow for the
  // same URL.  A Set lets warm-start new URLs through normally.
  static final Set<String> _inFlightUrls = {};

  /// Returns true and marks [url] in-flight when it is safe to proceed.
  /// Returns false (and does nothing) when the URL is already being handled.
  static bool _claimUrl(String url) {
    return _inFlightUrls.add(url);
  }

  static void _releaseUrl(String url) {
    _inFlightUrls.remove(url);
  }

  /// Initializes listening for Android incoming intents (cold-start & runtime).
  static void initIntentHandler(GlobalKey<NavigatorState> navigatorKey) {
    if (_intentHandlerInitialized) return;
    _intentHandlerInitialized = true;

    browserChannel.setMethodCallHandler((call) async {
      if (call.method == 'onIncomingUrl') {
        final args = call.arguments;
        final url = (args is Map) ? args['url'] as String? : null;
        if (url != null && url.isNotEmpty && _claimUrl(url)) {
          // Schedule navigation after the current frame so the widget
          // tree is fully mounted before we push a route.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final navState = navigatorKey.currentState;
            if (navState != null && navState.mounted) {
              await navigateWithProtection(navState.context, targetUrl: url);
            }
            _releaseUrl(url);
          });
        }
      }
    });

    // Check cold-start initial intent.
    // On cold start, Kotlin may deliver the URL via EITHER pendingIntentUrl
    // (→ onIncomingUrl via configureFlutterEngine) OR via getInitialIntent,
    // but never both, because configureFlutterEngine clears pendingIntentUrl
    // before returning.  The _claimUrl guard still protects against any edge
    // case where both paths race.
    browserChannel
        .invokeMethod<String>('getInitialIntent')
        .then((url) {
          if (url != null && url.isNotEmpty && _claimUrl(url)) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final navState = navigatorKey.currentState;
              if (navState != null && navState.mounted) {
                await navigateWithProtection(navState.context, targetUrl: url);
              }
              _releaseUrl(url);
            });
          }
        })
        .catchError((_) {});
  }

  /// Evaluates [targetUrl] and prompts user before opening.
  /// If the URL is high or critical risk, navigation is blocked until the
  /// user explicitly acknowledges and overrides the security warning.
  static Future<void> navigateWithProtection(
    BuildContext context, {
    required String targetUrl,
    ScanResult? existingResult,
  }) async {
    // Show quick analyzing indicator if not already analyzed
    ScanResult analysisResult;
    if (existingResult != null && existingResult.type == ScanType.link) {
      analysisResult = existingResult;
    } else {
      analysisResult = await UrlAnalysisService.analyzeUrl(targetUrl);
    }

    if (!context.mounted) return;

    // Use the shared pure decision function.
    final decision = evaluateNavigation(
      targetUrl: targetUrl,
      analysisResult: analysisResult,
    );

    if (decision == NavigationDecision.blocked) {
      // Dangerous scheme — never open, optionally show a toast.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blocked: dangerous URI scheme.')),
      );
      return;
    }

    if (decision == NavigationDecision.warn) {
      // Show explicit Pre-Navigation Warning Modal
      final proceed = await showPreNavigationWarning(
        context,
        targetUrl: targetUrl,
        result: analysisResult,
      );

      if (proceed != true) {
        // User cancelled navigation - return to safety
        return;
      }
    }

    if (!context.mounted) return;

    // Launch Native Android Protected Browser via MethodChannel
    try {
      final success = await browserChannel.invokeMethod<bool>('openBrowser', {
        'url': targetUrl,
        'scanResult': analysisResult.toJson(),
      });
      if (success != true && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SafeBrowserScreen(
              targetUrl: targetUrl,
              scanResult: analysisResult,
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SafeBrowserScreen(
              targetUrl: targetUrl,
              scanResult: analysisResult,
            ),
          ),
        );
      }
    }
  }

  /// Displays the full Pre-Navigation Warning BottomSheet / Dialog.
  /// Returns `true` only if the user explicitly confirms proceeding.
  static Future<bool?> showPreNavigationWarning(
    BuildContext context, {
    required String targetUrl,
    required ScanResult result,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _PreNavigationWarningSheet(targetUrl: targetUrl, result: result),
    );
  }
}

class _PreNavigationWarningSheet extends StatelessWidget {
  final String targetUrl;
  final ScanResult result;

  const _PreNavigationWarningSheet({
    required this.targetUrl,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger =
        result.riskLevel == RiskLevel.high ||
        result.riskLevel == RiskLevel.critical;
    final bannerColor = isDanger ? AppTheme.red : AppTheme.amber;
    final bannerBg = isDanger ? AppTheme.redLight : AppTheme.amberLight;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.grayBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Interception Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: bannerColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bannerColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDanger ? Icons.gpp_bad : Icons.warning_amber_rounded,
                    color: bannerColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Navigation Intercepted',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navyText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Threat Status: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          StatusChip(
                            riskLevel: result.riskLevel,
                            compact: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Target Destination:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.lavenderBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.grayBorder),
            ),
            child: SelectableText(
              targetUrl,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.navyText,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Key risks list
          if (result.warnings.isNotEmpty) ...[
            const Text(
              'Why DigiLens Paused Navigation:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.navyText,
              ),
            ),
            const SizedBox(height: 8),
            ...result.warnings
                .take(2)
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.cancel_outlined,
                          size: 16,
                          color: AppTheme.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            w.title,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.navyLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 16),
          ],

          // Cancel & Return to Safety (Primary Action)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.indigo,
                foregroundColor: AppTheme.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text(
                'Cancel & Return to Safety (Recommended)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bypass Override button (Secondary, Warning)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.red,
                side: const BorderSide(color: AppTheme.red, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'I Understand the Risks — Open Safely in Sandboxed Viewer',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
