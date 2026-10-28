import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/theme/app_theme.dart';
import 'package:digilens/components/status_chip.dart';
import 'package:digilens/services/url_analysis_service.dart';
import 'package:digilens/services/parental_control_service.dart';
import 'package:digilens/components/parental_pin_modal.dart';
import 'package:digilens/screens/safe_browser_screen.dart';

// ─── Dangerous-scheme list ──────────────────────────────────────────────────
/// Schemes that must NEVER be passed to a browser or WebView for execution.
/// Visible for testing so that the exact same list governs both production
/// navigation decisions and unit-test assertions.
const Set<String> dangerousSchemes = {
  'javascript',
  'data',
  'vbscript',
  'blob',
  'file',
  'intent',
};

/// Schemes that DigiLens allows through to the safe-browser viewer.
const Set<String> permittedSchemes = {'http', 'https'};

// ─── Pure navigation-decision function ──────────────────────────────────────

enum NavigationDecision {
  /// The URL scheme is dangerous (javascript:, data:, file:, intent:, etc.) — block outright.
  blocked,

  /// Heuristic analysis flagged the URL at medium risk or above — the caller
  /// should present a warning and let the user decide.
  warn,

  /// The URL appears safe — proceed to the in-app browser viewer.
  allow,
}

/// Decide what the navigation guard should do for [targetUrl] given its
/// [analysisResult].
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

  // 2. Risk-based decision from heuristic analysis.
  final isRisky =
      analysisResult.riskLevel == RiskLevel.medium ||
      analysisResult.riskLevel == RiskLevel.high ||
      analysisResult.riskLevel == RiskLevel.critical;

  return isRisky ? NavigationDecision.warn : NavigationDecision.allow;
}

/// Service responsible for intercepting link navigation and warning users
/// before suspicious links are opened, with fine-grained Parental Control PIN checks:
/// - Safe and Low risk: Bypass PIN approval.
/// - Medium and High risk: Require parental PIN approval.
/// - Critical risk: Blocked by default under parental control.
/// - Dangerous schemes: Blocked outright regardless of state.
class PreNavigationGuard {
  static const MethodChannel browserChannel = MethodChannel(
    'com.example.digilens/browser',
  );
  static bool _intentHandlerInitialized = false;

  // ── Duplicate-intent guard ───────────────────────────────────────────────
  static final Set<String> _inFlightUrls = {};

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
  /// 1. Safe or Low-risk links: Bypass parental PIN approval.
  /// 2. Medium-risk links: Require parental PIN approval before opening.
  /// 3. High-risk links: Require parental PIN approval before opening, while retaining risk warning.
  /// 4. Critical-risk links: Blocked by default and show security warning. PIN alone cannot bypass.
  /// 5. Dangerous URI schemes: Blocked unconditionally.
  static Future<void> navigateWithProtection(
    BuildContext context, {
    required String targetUrl,
    ScanResult? existingResult,
  }) async {
    // 1. Analyze URL first to determine risk level and scheme validity
    ScanResult analysisResult;
    if (existingResult != null && existingResult.type == ScanType.link) {
      analysisResult = existingResult;
    } else {
      analysisResult = await UrlAnalysisService.analyzeUrl(targetUrl);
    }

    if (!context.mounted) return;

    // 2. Check for dangerous or unsupported schemes
    final decision = evaluateNavigation(
      targetUrl: targetUrl,
      analysisResult: analysisResult,
    );

    if (decision == NavigationDecision.blocked) {
      await ParentalControlService.instance.recordActivity(
        eventType: 'website_access',
        details: 'Blocked dangerous or unsupported URI scheme',
        status: 'blocked',
        targetUrl: targetUrl,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blocked: dangerous URI scheme.')),
        );
      }
      return;
    }

    final bool isParentalActive = ParentalControlService.instance.isEnabled;

    // 3. Critical-risk Protection under Parental Web Guard
    // Block by default and show security warning; PIN approval alone does not bypass critical threat.
    if (isParentalActive && analysisResult.riskLevel == RiskLevel.critical) {
      await ParentalControlService.instance.recordActivity(
        eventType: 'website_access',
        details: 'Blocked critical-risk threat destination under Parental Control',
        status: 'blocked',
        targetUrl: targetUrl,
      );
      if (context.mounted) {
        await showPreNavigationWarning(
          context,
          targetUrl: targetUrl,
          result: analysisResult,
        );
      }
      return;
    }

    // 4. Parental Web Guard PIN Check for Medium or High risk links
    // (Safe and Low-risk links bypass PIN approval)
    final bool isMediumOrHighRisk =
        analysisResult.riskLevel == RiskLevel.medium ||
        analysisResult.riskLevel == RiskLevel.high;

    if (isParentalActive && isMediumOrHighRisk) {
      final hasPin = await ParentalControlService.instance.hasPinSet();
      if (hasPin) {
        if (!context.mounted) return;
        final verified = await ParentalPinModal.show(
          context,
          title: 'Parental PIN Required (${analysisResult.riskLevel.name.toUpperCase()} Risk)',
          subtitle: 'Parental Web Guard requires a 6-digit PIN to approve opening this ${analysisResult.riskLevel.name}-risk link:\n$targetUrl',
        );

        if (!verified) {
          await ParentalControlService.instance.recordActivity(
            eventType: 'website_access',
            details: 'Risky website access cancelled (${analysisResult.riskLevel.name} risk, PIN verification declined)',
            status: 'cancelled',
            targetUrl: targetUrl,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigation cancelled by Parental Control.')),
            );
          }
          return;
        }
      }
    }

    // 5. Existing Risk Warning Modal
    // Retain risk-warning UI for high-risk links under Parental Control,
    // or for medium/high/critical when Parental Control is disabled.
    final bool shouldShowWarning = (!isParentalActive && decision == NavigationDecision.warn) ||
        (isParentalActive && analysisResult.riskLevel == RiskLevel.high);

    if (shouldShowWarning) {
      if (!context.mounted) return;
      final proceed = await showPreNavigationWarning(
        context,
        targetUrl: targetUrl,
        result: analysisResult,
      );

      if (proceed != true) {
        await ParentalControlService.instance.recordActivity(
          eventType: 'website_access',
          details: 'User cancelled after risk warning (${analysisResult.riskLevel.name} risk)',
          status: 'cancelled',
          targetUrl: targetUrl,
        );
        return;
      }
    }

    if (!context.mounted) return;

    // 6. Record successful navigation access (single clean record)
    final String openDetails = isParentalActive && isMediumOrHighRisk
        ? 'Opened ${analysisResult.riskLevel.name}-risk website with parental PIN approval'
        : 'Opened ${analysisResult.riskLevel.name} website';

    await ParentalControlService.instance.recordActivity(
      eventType: 'website_access',
      details: openDetails,
      status: 'approved',
      targetUrl: targetUrl,
    );

    // 7. Launch Native Android Protected Browser via MethodChannel
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
