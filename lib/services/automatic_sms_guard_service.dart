import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/services/sms_analysis_service.dart';
import 'package:digilens/services/scan_history_service.dart';

/// Service managing automatic incoming SMS monitoring, permissions,
/// privacy consent, duplicate filtering, and hybrid contextual analysis.
class AutomaticSmsGuardService {
  AutomaticSmsGuardService._();
  static final AutomaticSmsGuardService instance = AutomaticSmsGuardService._();

  static const MethodChannel _smsChannel =
      MethodChannel('com.example.digilens/sms_guard');

  bool _isProtectionEnabled = true;
  bool _isCloudAiEnabled = true;
  String _backendUrl = 'http://10.0.2.2:8000/api/v1/analyze-sms';
  http.Client? _clientOverride;

  // Track recent SMS hash/id and timestamp to prevent duplicate scans
  final Set<String> _processedMessageHashes = {};
  final List<ScanResult> _recentDetections = [];
  final ValueNotifier<List<ScanResult>> detectionsNotifier =
      ValueNotifier<List<ScanResult>>([]);

  // Stream controller to broadcast detected threat results to UI
  final StreamController<ScanResult> _threatStreamController =
      StreamController<ScanResult>.broadcast();
  Stream<ScanResult> get threatStream => _threatStreamController.stream;

  // Global callback to navigate when notification is tapped
  static void Function(ScanResult result, String scannedInput)? onNotificationTapNavigation;

  bool get isProtectionEnabled => _isProtectionEnabled;
  bool get isCloudAiEnabled => _isCloudAiEnabled;
  List<ScanResult> get recentDetections => List.unmodifiable(_recentDetections);

  void setProtectionEnabled(bool enabled) {
    _isProtectionEnabled = enabled;
  }

  void setCloudAiEnabled(bool enabled) {
    _isCloudAiEnabled = enabled;
  }

  void configure({
    String? backendUrl,
    http.Client? client,
  }) {
    if (backendUrl != null) _backendUrl = backendUrl;
    if (client != null) _clientOverride = client;
  }

  /// Initialize native channel listener for incoming SMS and notification taps
  void initialize() {
    _smsChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onIncomingSms':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final sender = args['sender'] as String? ?? 'Unknown';
          final body = args['body'] as String? ?? '';
          await processIncomingSms(sender: sender, body: body);
          break;
        case 'onSmsNotificationTapped':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final sender = args['sender'] as String? ?? 'Unknown';
          final body = args['body'] as String? ?? '';
          final result = await processIncomingSms(sender: sender, body: body, fromTap: true);
          if (result != null && onNotificationTapNavigation != null) {
            onNotificationTapNavigation!(result, body);
          }
          break;
        default:
          break;
      }
    });

    // Check for any pending SMS received while app was cold starting
    _checkPendingSms();
  }

  Future<void> _checkPendingSms() async {
    try {
      final res = await _smsChannel.invokeMethod('getPendingSms');
      if (res != null && res is Map) {
        final args = Map<String, dynamic>.from(res);
        final sender = args['sender'] as String? ?? 'Unknown';
        final body = args['body'] as String? ?? '';
        final fromTap = args['fromNotification'] == 'true';
        if (body.isNotEmpty) {
          final result = await processIncomingSms(sender: sender, body: body, fromTap: fromTap);
          if (fromTap && result != null && onNotificationTapNavigation != null) {
            onNotificationTapNavigation!(result, body);
          }
        }
      }
    } catch (_) {}
  }

  /// Request SMS and notification permissions required for automatic detection
  Future<Map<String, bool>> requestPermissions() async {
    final smsStatus = await Permission.sms.request();
    final notificationStatus = await Permission.notification.request();

    return {
      'sms': smsStatus.isGranted,
      'notification': notificationStatus.isGranted,
    };
  }

  /// Check current permission statuses
  Future<Map<String, bool>> checkPermissions() async {
    final smsGranted = await Permission.sms.isGranted;
    final notificationGranted = await Permission.notification.isGranted;

    return {
      'sms': smsGranted,
      'notification': notificationGranted,
    };
  }

  /// Process an incoming SMS text with deduplication and hybrid contextual analysis
  Future<ScanResult?> processIncomingSms({
    required String sender,
    required String body,
    bool fromTap = false,
  }) async {
    if (!_isProtectionEnabled && !fromTap) {
      return null;
    }

    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    // Deduplication via hash of sender + content
    final messageHash = '$sender:${trimmed.hashCode}';
    if (_processedMessageHashes.contains(messageHash) && !fromTap) {
      return null;
    }
    _processedMessageHashes.add(messageHash);

    // Limit deduplication cache size
    if (_processedMessageHashes.length > 200) {
      _processedMessageHashes.clear();
      _processedMessageHashes.add(messageHash);
    }

    ScanResult result;

    try {
      // Phase 4: Hybrid Scam Analysis (Cloud Gemini or Local Heuristics)
      if (_isCloudAiEnabled) {
        result = await _analyzeWithCloudAi(sender: sender, body: trimmed);
      } else {
        result = await SmsAnalysisService.analyzeSms(trimmed, sender: sender);
      }
    } catch (e) {
      // Fallback if both cloud and heuristic execution encounter an issue
      result = ScanResult(
        id: 'sms-fallback-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        type: ScanType.sms,
        riskLevel: RiskLevel.medium,
        title: 'Analysis Fallback — Review Message',
        description: 'Automated analysis timed out or encountered an error. Please inspect the message content below carefully.',
        warnings: [
          WarningIndicator(
            title: 'Scan Error / Incomplete',
            description: 'Unable to reach backend: $e',
            icon: Icons.error_outline,
          ),
        ],
        recommendation: 'Exercise caution and verify the sender before replying or clicking links.',
        analysisMethod: AnalysisMethod.localHeuristics,
        originalInput: trimmed,
        sender: sender,
      );
    }

    // Record to persistent scan history
    ScanHistoryService.instance.recordScan(rawInput: trimmed, result: result);

    // If suspicious, broadcast and register in recent detections
    if (result.riskLevel.index >= RiskLevel.medium.index) {
      _recentDetections.insert(0, result);
      detectionsNotifier.value = List.unmodifiable(_recentDetections);
      _threatStreamController.add(result);
    }

    return result;
  }

  /// Communicates with FastAPI Gemini backend for contextual smishing analysis
  Future<ScanResult> _analyzeWithCloudAi({
    required String sender,
    required String body,
  }) async {
    final client = _clientOverride ?? http.Client();
    try {
      final response = await client.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': sender,
          'body': body,
          'language': 'en-IN',
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseBackendResponse(data, body, sender);
      }
    } catch (_) {
      // Gracefully fall back to local heuristics on timeout or offline
    } finally {
      if (_clientOverride == null) {
        client.close();
      }
    }

    // Fallback to local heuristic rules
    return SmsAnalysisService.analyzeSms(body, sender: sender);
  }

  ScanResult _parseBackendResponse(
    Map<String, dynamic> data,
    String rawBody,
    String sender,
  ) {
    final riskLevelStr = (data['risk_level'] as String? ?? 'safe').toLowerCase();
    RiskLevel riskLevel;
    switch (riskLevelStr) {
      case 'critical':
        riskLevel = RiskLevel.critical;
        break;
      case 'high':
        riskLevel = RiskLevel.high;
        break;
      case 'medium':
        riskLevel = RiskLevel.medium;
        break;
      case 'low':
        riskLevel = RiskLevel.low;
        break;
      default:
        riskLevel = RiskLevel.safe;
    }

    final riskScore = (data['risk_score'] as num? ?? 0).toInt();
    final scamType = data['scam_type'] as String? ?? 'unknown';
    final recommendedAction =
        data['recommended_action'] as String? ?? 'Exercise caution.';

    final warnings = <WarningIndicator>[];
    if (data['evidence'] is List) {
      for (final item in data['evidence'] as List) {
        if (item is Map<String, dynamic>) {
          warnings.add(
            WarningIndicator(
              title: item['title'] as String? ?? 'SMS Threat Indicator',
              description: item['description'] as String? ?? '',
              icon: Icons.warning_amber_rounded,
            ),
          );
        }
      }
    }

    String title;
    switch (scamType) {
      case 'digital_arrest':
        title = 'Law Enforcement / Digital Arrest Threat';
        break;
      case 'otp_theft':
        title = 'Suspicious OTP / Credential Harvesting';
        break;
      case 'fake_kyc':
        title = 'Bank Account / KYC Suspension Phishing';
        break;
      case 'utility_threat':
        title = 'Utility Disconnection Extortion';
        break;
      case 'lottery_scam':
        title = 'Advance-Fee Prize / Lottery Scam';
        break;
      default:
        title = riskLevel == RiskLevel.safe
            ? 'No Obvious Fraud Indicators'
            : 'Suspicious Incoming SMS Detected';
    }

    return ScanResult(
      id: 'sms-ai-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      type: ScanType.sms,
      riskLevel: riskLevel,
      riskScore: riskScore,
      title: title,
      description: warnings.isNotEmpty
          ? warnings.first.description
          : 'Contextual AI detected suspicious smishing patterns.',
      warnings: warnings,
      recommendation: recommendedAction,
      analysisMethod: AnalysisMethod.mlModel,
      originalInput: rawBody,
      sender: sender,
    );
  }
}
