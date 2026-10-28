import 'package:flutter/material.dart';
import 'package:digilens/theme/app_theme.dart';
import 'package:digilens/services/live_audio_guard_service.dart';

class LiveCallProtectionScreen extends StatefulWidget {
  const LiveCallProtectionScreen({super.key});

  @override
  State<LiveCallProtectionScreen> createState() => _LiveCallProtectionScreenState();
}

class _LiveCallProtectionScreenState extends State<LiveCallProtectionScreen> {
  final LiveAudioGuardService _guardService = LiveAudioGuardService.instance;
  int _lastHandledAlertVersion = 0;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _guardService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _guardService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {});

    final alert = _guardService.currentThreatAlert;
    final version = _guardService.threatAlertVersion;

    if (alert == null) {
      _lastHandledAlertVersion = 0;
    } else if (version != _lastHandledAlertVersion && !_isDialogShowing) {
      _lastHandledAlertVersion = version;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDialogShowing && _guardService.currentThreatAlert != null) {
          _showThreatAlertPopup(_guardService.currentThreatAlert!);
        }
      });
    }
  }

  void _showThreatAlertPopup(ThreatAlert alert) {
    if (!mounted || _isDialogShowing) return;
    _isDialogShowing = true;

    final riskLevelStr = alert.riskLevel.name.toUpperCase();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.red, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🚨 SCAM ALERT: ${alert.title}',
                style: const TextStyle(fontSize: 16, color: AppTheme.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.redLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Risk Level: $riskLevelStr',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.red, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Detected Speech:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.mutedText),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.lavenderBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.grayBorder),
                ),
                child: Text(
                  alert.transcript.isNotEmpty ? alert.transcript : '(No transcript captured)',
                  style: const TextStyle(fontSize: 13, color: AppTheme.navyText, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Why this is dangerous:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.mutedText),
              ),
              const SizedBox(height: 4),
              Text(
                alert.reason,
                style: const TextStyle(fontSize: 12, color: AppTheme.navyText, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.redLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.phone_disabled, color: AppTheme.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hang up immediately! Do not transfer funds or follow instructions.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.red, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _isDialogShowing = false;
            },
            child: const Text('Dismiss', style: TextStyle(color: AppTheme.mutedText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _guardService.stopLiveGuard();
              Navigator.of(ctx).pop();
              _isDialogShowing = false;
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red,
              foregroundColor: AppTheme.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Stop monitoring', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = _guardService.status == AudioGuardStatus.listening;
    final isPermanentlyDenied =
        _guardService.status == AudioGuardStatus.permissionPermanentlyDenied;
    final isDenied = _guardService.status == AudioGuardStatus.permissionDenied;

    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Text(
          'Live Call Protection & Guard',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner / Radar Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _guardService.isThreatDetected
                      ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
                      : isListening
                          ? [const Color(0xFF059669), const Color(0xFF10B981)]
                          : isPermanentlyDenied || isDenied
                              ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                              : [const Color(0xFF6366F1), const Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_guardService.isThreatDetected
                            ? Colors.red
                            : isListening
                                ? Colors.green
                                : isPermanentlyDenied
                                    ? Colors.red
                                    : AppTheme.indigo)
                        .withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _guardService.isThreatDetected
                          ? Icons.warning_amber_rounded
                          : isListening
                              ? Icons.mic
                              : isPermanentlyDenied || isDenied
                                  ? Icons.mic_off
                                  : Icons.security,
                      color: AppTheme.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _guardService.isThreatDetected
                              ? '🚨 Threat Detected — Scam Alert Active'
                              : isListening
                                  ? 'Live Guard Active'
                                  : isPermanentlyDenied
                                      ? 'Permission Required'
                                      : 'Microphone Guard Idle',
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _guardService.statusMessage,
                          style: TextStyle(
                            color: AppTheme.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Persistent Warning Banner / Card when threat is detected
            if (_guardService.isThreatDetected) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.redLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.red, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.red.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (_guardService.latestScanResult?.riskLevel.name ?? 'CRITICAL').toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'SCAM PATTERN DETECTED',
                                    style: TextStyle(
                                      color: AppTheme.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _guardService.lastAlertTitle ?? 'Suspicious Activity Detected',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navyText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.grayBorder, height: 1),
                    const SizedBox(height: 10),
                    Text(
                      _guardService.latestScanResult?.warnings.isNotEmpty == true
                          ? _guardService.latestScanResult!.warnings.first.description
                          : 'Suspicious audio matched known scam or extortion patterns.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.navyText, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.phone_disabled, color: AppTheme.red, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Recommendation: Disconnect call immediately. Do not transfer funds or follow instructions.',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isListening) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _guardService.stopLiveGuard(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.red,
                            side: const BorderSide(color: AppTheme.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.stop, size: 16),
                          label: const Text('Stop Monitoring Now', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Main Controls & Permission Action
            Text(
              'Microphone Permission & Control',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.grayBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.mic_none, color: AppTheme.indigo, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'RECORD_AUDIO Permission',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navyText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'DigiLens requests microphone access strictly when you explicitly start Live Audio Protection. '
                    'This allows the app to listen for scam keywords during calls.',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedText, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (isPermanentlyDenied) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.redLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Microphone permission is permanently denied in Android Settings. '
                        'Please tap below to open Android Settings → Apps → DigiLens → Permissions and enable Microphone manually.',
                        style: TextStyle(fontSize: 12, color: AppTheme.red, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _guardService.openSystemSettings(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.red,
                          foregroundColor: AppTheme.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text(
                          'Open Android Settings',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isListening
                            ? () => _guardService.stopLiveGuard()
                            : () => _guardService.startLiveGuard(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isListening ? AppTheme.red : AppTheme.indigo,
                          foregroundColor: AppTheme.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(isListening ? Icons.stop : Icons.play_arrow, size: 20),
                        label: Text(
                          isListening ? 'Stop Live Audio Guard' : 'Start Live Audio Guard',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Real-Time Speech Recognition Transcript & Amplitude Bar
            if (isListening || _guardService.liveTranscript.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Real-Time Speech Transcript',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (_guardService.liveTranscript.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _guardService.clearTranscript(),
                      icon: const Icon(Icons.clear, size: 14),
                      label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _guardService.isThreatDetected
                        ? AppTheme.red
                        : AppTheme.indigo.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _guardService.isThreatDetected ? Icons.warning_amber : Icons.mic,
                          size: 18,
                          color: _guardService.isThreatDetected ? AppTheme.red : AppTheme.indigo,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isListening ? 'Listening to speech...' : 'Transcript Captured',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _guardService.isThreatDetected ? AppTheme.red : AppTheme.navyText,
                          ),
                        ),
                        const Spacer(),
                        if (isListening)
                          SizedBox(
                            width: 60,
                            height: 12,
                            child: LinearProgressIndicator(
                              value: _guardService.currentAmplitude,
                              backgroundColor: AppTheme.lavenderBackground,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.indigo),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _guardService.liveTranscript.isEmpty
                          ? 'Speak near the microphone or use the simulation below to test speech recognition and scam analysis.'
                          : _guardService.liveTranscript,
                      style: TextStyle(
                        fontSize: 13,
                        color: _guardService.liveTranscript.isEmpty
                            ? AppTheme.mutedText
                            : AppTheme.navyText,
                        height: 1.5,
                        fontStyle: _guardService.liveTranscript.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    if (_guardService.isThreatDetected && _guardService.lastAlertTitle != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.redLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.gavel, color: AppTheme.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Risk Alert: ${_guardService.lastAlertTitle}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Demo Threat Simulation (for testing/hackathon judges)
            Text(
              'Simulate Live Threat (Testing Mode)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.grayBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Simulate incoming call audio matching "Digital Arrest" extortion script or test transcript recognition:',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedText, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _guardService.simulateThreatDetection(
                          'Digital Arrest Extortion Detected',
                          'CBI officer speaking. You are under digital arrest. Transfer 1 Lakh immediately.',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: AppTheme.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.warning_amber, size: 18),
                        label: const Text('Simulate Digital Arrest Threat'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _guardService.simulateThreatDetection(
                          'Bank Impersonation & OTP Theft',
                          'This is SBI branch manager. Tell me your OTP and CVV to verify your card.',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.indigo,
                          foregroundColor: AppTheme.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.security, size: 18),
                        label: const Text('Simulate Bank Scam'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Android Call-Audio Technical Limitation Explanation
            const Text(
              'Important Android Call Audio Limitation',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.navyText,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.grayBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppTheme.indigo),
                      SizedBox(width: 8),
                      Text(
                        'Why speakerphone is needed for cellular calls',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.indigo,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• RECORD_AUDIO Permission: Grants access to the device microphone, allowing the app to capture ambient room audio or audio played through the speakerphone during a phone call.\n\n'
                    '• Direct Call Audio Interception: Standard Android apps cannot directly tap into internal cellular call audio streams (remote caller\'s voice) due to strict OS privacy and security hardening.\n\n'
                    '• Privileged APIs: CAPTURE_AUDIO_OUTPUT requires signature-level permissions reserved strictly for system apps (OEM dialers). Third-party apps rely on speakerphone audio or Call Screening Service APIs.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.navyLight,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
