import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/services/scan_history_service.dart';
import 'package:digilens/services/voice_analysis_service.dart';

enum AudioGuardStatus {
  idle,
  requestingPermission,
  permissionDenied,
  permissionPermanentlyDenied,
  initializing,
  listening,
  unavailable,
  error,
}

/// Data payload representing an actionable live threat alert event.
class ThreatAlert {
  final String id;
  final String title;
  final String reason;
  final String transcript;
  final RiskLevel riskLevel;
  final DateTime timestamp;

  const ThreatAlert({
    required this.id,
    required this.title,
    required this.reason,
    required this.transcript,
    required this.riskLevel,
    required this.timestamp,
  });
}

/// Interface for speech recognition engine to allow testing and platform abstraction.
abstract class ISpeechRecognizer {
  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
    bool debugLogging = false,
  });
  bool get isAvailable;
  bool get isListening;
  Future<void> listen({
    required stt.SpeechResultListener onResult,
    stt.SpeechSoundLevelChange? onSoundLevelChange,
    stt.SpeechListenOptions? listenOptions,
  });
  Future<void> stop();
  Future<void> cancel();
}

/// Default implementation wrapping speech_to_text package.
class DefaultSpeechRecognizer implements ISpeechRecognizer {
  final stt.SpeechToText _speech;

  DefaultSpeechRecognizer([stt.SpeechToText? speech])
      : _speech = speech ?? stt.SpeechToText();

  @override
  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
    bool debugLogging = false,
  }) {
    return _speech.initialize(
      onError: onError,
      onStatus: onStatus,
      debugLogging: debugLogging,
    );
  }

  @override
  bool get isAvailable => _speech.isAvailable;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<void> listen({
    required stt.SpeechResultListener onResult,
    stt.SpeechSoundLevelChange? onSoundLevelChange,
    stt.SpeechListenOptions? listenOptions,
  }) {
    return _speech.listen(
      onResult: onResult,
      onSoundLevelChange: onSoundLevelChange,
      listenOptions: listenOptions,
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

/// Service managing microphone permissions, live speech-to-text recognition,
/// and live audio monitoring for the Live Call Protection feature.
class LiveAudioGuardService extends ChangeNotifier {
  static final LiveAudioGuardService instance = LiveAudioGuardService._internal();

  LiveAudioGuardService._internal({ISpeechRecognizer? speechRecognizer}) {
    _speech = speechRecognizer ?? DefaultSpeechRecognizer();
  }

  ISpeechRecognizer _speech = DefaultSpeechRecognizer();
  final VoiceAnalysisService _voiceAnalysisService = VoiceAnalysisService();

  AudioGuardStatus _status = AudioGuardStatus.idle;
  String _statusMessage = 'Ready to start live audio guard';
  double _currentAmplitude = 0.0;
  bool _isThreatDetected = false;
  String? _lastAlertTitle;
  String _liveTranscript = '';
  ScanResult? _latestScanResult;
  ThreatAlert? _currentThreatAlert;
  int _threatAlertVersion = 0;
  final Set<String> _alertedThreatKeys = {};
  final Set<String> _recordedThreatTitles = {};

  final List<String> _confirmedPhrases = [];
  String _currentPartial = '';

  bool _isInitialized = false;
  String _lastAnalyzedTranscript = '';
  Timer? _restartTimer;
  int _restartAttempts = 0;
  static const int _maxRapidRestarts = 5;
  DateTime? _lastRestartTime;

  bool get isRestartScheduled => _restartTimer?.isActive ?? false;

  AudioGuardStatus get status => _status;
  String get statusMessage => _statusMessage;
  double get currentAmplitude => _currentAmplitude;
  bool get isThreatDetected => _isThreatDetected;
  String? get lastAlertTitle => _lastAlertTitle;
  String get liveTranscript => _liveTranscript;
  ScanResult? get latestScanResult => _latestScanResult;
  ThreatAlert? get currentThreatAlert => _currentThreatAlert;
  int get threatAlertVersion => _threatAlertVersion;

  @visibleForTesting
  void setSpeechRecognizerForTesting(ISpeechRecognizer recognizer) {
    _speech = recognizer;
    _isInitialized = false;
  }

  /// Explicitly request microphone permission when user starts Live Audio Detection.
  Future<bool> requestMicrophonePermission() async {
    _status = AudioGuardStatus.requestingPermission;
    _statusMessage = 'Checking microphone permission...';
    notifyListeners();

    try {
      var status = await Permission.microphone.status;

      if (status.isGranted) {
        _status = AudioGuardStatus.idle;
        _statusMessage = 'Microphone permission granted.';
        notifyListeners();
        return true;
      }

      // Request permission
      status = await Permission.microphone.request();

      if (status.isGranted) {
        _status = AudioGuardStatus.idle;
        _statusMessage = 'Microphone permission granted.';
        notifyListeners();
        return true;
      } else if (status.isPermanentlyDenied) {
        _status = AudioGuardStatus.permissionPermanentlyDenied;
        _statusMessage =
            'Microphone permission is permanently denied. Please enable it in Android Settings.';
        notifyListeners();
        return false;
      } else {
        _status = AudioGuardStatus.permissionDenied;
        _statusMessage =
            'Microphone permission was denied. Live audio guard requires microphone access.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AudioGuardStatus.error;
      _statusMessage = 'Permission request error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start live audio monitoring and speech recognition if permission is granted.
  Future<void> startLiveGuard() async {
    if (_status == AudioGuardStatus.listening) return;

    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) return;

    _status = AudioGuardStatus.initializing;
    _statusMessage = 'Initializing speech recognition engine...';
    notifyListeners();

    try {
      if (!_isInitialized) {
        _isInitialized = await _speech.initialize(
          onError: _onSpeechError,
          onStatus: _onSpeechStatus,
          debugLogging: false,
        );
      }

      if (!_isInitialized || !_speech.isAvailable) {
        _status = AudioGuardStatus.unavailable;
        _statusMessage =
            'Speech recognition service is unavailable on this device. You can still use transcript-testing mode.';
        notifyListeners();
        return;
      }

      // Reset state for new listening session
      _status = AudioGuardStatus.listening;
      _statusMessage = 'Live Call Audio Guard active (Listening...)';
      _isThreatDetected = false;
      _lastAlertTitle = null;
      _latestScanResult = null;
      _currentThreatAlert = null;
      _threatAlertVersion = 0;
      _alertedThreatKeys.clear();
      _confirmedPhrases.clear();
      _currentPartial = '';
      _liveTranscript = '';
      _lastAnalyzedTranscript = '';
      _recordedThreatTitles.clear();
      notifyListeners();

      await _startListeningSession();
    } catch (e) {
      _status = AudioGuardStatus.error;
      _statusMessage = 'Failed to start speech recognition: $e';
      notifyListeners();
    }
  }

  Future<void> _startListeningSession() async {
    if (_status != AudioGuardStatus.listening) return;

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        onSoundLevelChange: _onSoundLevelChange,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          onDevice: true, // Prefer on-device recognition for privacy
          cancelOnError: false, // Handle errors gracefully without sudden termination
          listenMode: stt.ListenMode.dictation,
          listenFor: const Duration(minutes: 15),
          pauseFor: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (_status == AudioGuardStatus.listening && !isRestartScheduled) {
        _statusMessage = 'Listening session error: $e';
        notifyListeners();
      }
    }
  }

  void _commitPhrase(String phrase) {
    final clean = phrase.trim();
    if (clean.isEmpty) return;

    // Prevent duplicate consecutive chunks
    if (_confirmedPhrases.isNotEmpty &&
        _confirmedPhrases.last.toLowerCase() == clean.toLowerCase()) {
      return;
    }

    _confirmedPhrases.add(clean);
  }

  String _buildTranscript() {
    if (_confirmedPhrases.isEmpty) {
      return _currentPartial;
    }
    if (_currentPartial.isEmpty) {
      return _confirmedPhrases.join(' ');
    }
    return '${_confirmedPhrases.join(' ')} $_currentPartial';
  }

  @visibleForTesting
  void handleSpeechResult(SpeechRecognitionResult result) {
    _onSpeechResult(result);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_status != AudioGuardStatus.listening) return;

    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;

    if (result.finalResult) {
      _commitPhrase(words);
      _currentPartial = '';
    } else {
      _currentPartial = words;
    }

    final updatedTranscript = _buildTranscript();
    if (updatedTranscript == _liveTranscript) return;

    _liveTranscript = updatedTranscript;
    notifyListeners();

    // Analyze incremental updates
    _analyzeTranscriptIncrementally(updatedTranscript, result.finalResult);
  }

  Future<void> _analyzeTranscriptIncrementally(String transcript, bool isFinal) async {
    final clean = transcript.trim();
    if (clean.isEmpty || clean == _lastAnalyzedTranscript) return;

    // Debounce small changes unless it is a final result
    if (!isFinal &&
        clean.length >= _lastAnalyzedTranscript.length &&
        (clean.length - _lastAnalyzedTranscript.length) < 8) {
      return;
    }

    _lastAnalyzedTranscript = clean;

    try {
      final result = await _voiceAnalysisService.classifyTranscript(clean);
      _latestScanResult = result;

      if (result.riskLevel == RiskLevel.high || result.riskLevel == RiskLevel.critical) {
        _isThreatDetected = true;
        _lastAlertTitle = result.title;
        _statusMessage = 'ALERT: ${result.title}';

        final reason = result.warnings.isNotEmpty
            ? result.warnings.first.description
            : (result.description.isNotEmpty
                ? result.description
                : 'Suspicious audio pattern matched known vishing or extortion scripts.');

        // Prevent duplicate popups for the same suspicious phrase during partial streaming
        final isAlreadyAlerted = result.warnings.isNotEmpty
            ? result.warnings.any((w) => _alertedThreatKeys.contains(w.title))
            : _alertedThreatKeys.contains(result.title);

        if (!isAlreadyAlerted) {
          if (result.warnings.isNotEmpty) {
            for (final w in result.warnings) {
              _alertedThreatKeys.add(w.title);
            }
          } else {
            _alertedThreatKeys.add(result.title);
          }
          _threatAlertVersion++;
          _currentThreatAlert = ThreatAlert(
            id: 'alert-${DateTime.now().millisecondsSinceEpoch}',
            title: result.title,
            reason: reason,
            transcript: clean,
            riskLevel: result.riskLevel,
            timestamp: DateTime.now(),
          );
        }

        notifyListeners();

        // Record scan once per threat pattern to avoid polluting history
        if (!_recordedThreatTitles.contains(result.title)) {
          _recordedThreatTitles.add(result.title);
          ScanHistoryService.instance.recordScan(
            rawInput: clean,
            result: result,
          );
        }
      }
    } catch (e) {
      debugPrint('VoiceAnalysisService classification error: $e');
    }
  }

  void _onSoundLevelChange(double level) {
    try {
      double normalized = (level + 10) / 20.0;
      _currentAmplitude = normalized.clamp(0.0, 1.0);
      notifyListeners();
    } catch (_) {
      _currentAmplitude = level.abs() / 10.0;
      if (_currentAmplitude > 1.0) _currentAmplitude = 1.0;
      notifyListeners();
    }
  }

  @visibleForTesting
  void handleSpeechError(SpeechRecognitionError error) {
    _onSpeechError(error);
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (_status != AudioGuardStatus.listening) return;

    // Common non-fatal pauses/timeouts on Android SpeechRecognizer
    if (error.errorMsg == 'error_no_match' || error.errorMsg == 'error_speech_timeout') {
      _scheduleRestart();
      return;
    }

    if (error.errorMsg == 'error_network' || error.errorMsg == 'error_network_timeout') {
      _statusMessage = 'Speech recognition requires network connection or offline speech packs.';
    } else {
      _statusMessage = 'Speech recognition notice: ${error.errorMsg}';
    }
    notifyListeners();
  }

  @visibleForTesting
  void handleSpeechStatus(String status) {
    _onSpeechStatus(status);
  }

  void _onSpeechStatus(String status) {
    if (_status != AudioGuardStatus.listening) return;

    if (status == 'notListening' || status == 'done') {
      if (_currentPartial.isNotEmpty) {
        _commitPhrase(_currentPartial);
        _currentPartial = '';
        _liveTranscript = _buildTranscript();
        notifyListeners();
        _analyzeTranscriptIncrementally(_liveTranscript, true);
      }
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (_status != AudioGuardStatus.listening || isRestartScheduled) return;
    _restartTimer?.cancel();

    final now = DateTime.now();
    if (_lastRestartTime != null && now.difference(_lastRestartTime!) < const Duration(seconds: 2)) {
      _restartAttempts++;
    } else {
      _restartAttempts = 0;
    }
    _lastRestartTime = now;

    if (_restartAttempts >= _maxRapidRestarts) {
      _restartTimer = Timer(const Duration(seconds: 3), () {
        if (_status == AudioGuardStatus.listening) {
          _restartAttempts = 0;
          _startListeningSession();
        }
      });
      return;
    }

    _restartTimer = Timer(const Duration(milliseconds: 350), () {
      if (_status == AudioGuardStatus.listening) {
        _startListeningSession();
      }
    });
  }

  /// Stop live audio monitoring and release speech recognition resources.
  Future<void> stopLiveGuard() async {
    _restartTimer?.cancel();
    _status = AudioGuardStatus.idle;
    _statusMessage = 'Live Audio Guard paused.';
    _currentAmplitude = 0.0;
    _currentPartial = '';
    try {
      await _speech.stop();
    } catch (_) {}
    notifyListeners();
  }

  /// Open Android system settings for this app.
  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  /// Clear the current recognized transcript.
  void clearTranscript() {
    _confirmedPhrases.clear();
    _currentPartial = '';
    _liveTranscript = '';
    _lastAnalyzedTranscript = '';
    _isThreatDetected = false;
    _lastAlertTitle = null;
    _latestScanResult = null;
    _alertedThreatKeys.clear();
    _recordedThreatTitles.clear();
    notifyListeners();
  }

  /// Simulate detection of a suspicious call phrase during live monitoring (for testing/demo).
  void simulateThreatDetection(String threatTitle, String transcript) {
    _isThreatDetected = true;
    _lastAlertTitle = threatTitle;
    _statusMessage = 'ALERT: $threatTitle detected!';
    _liveTranscript = transcript;
    _alertedThreatKeys.add(threatTitle);
    _threatAlertVersion++;
    _currentThreatAlert = ThreatAlert(
      id: 'sim-${DateTime.now().millisecondsSinceEpoch}',
      title: threatTitle,
      reason: 'Suspicious audio pattern matched known vishing scripts ($threatTitle).',
      transcript: transcript,
      riskLevel: RiskLevel.critical,
      timestamp: DateTime.now(),
    );
    notifyListeners();

    ScanHistoryService.instance.recordScan(
      rawInput: transcript,
      result: ScanResult(
        id: 'live-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        type: ScanType.voice,
        riskLevel: RiskLevel.critical,
        title: threatTitle,
        description: 'Detected during live audio guard monitoring.',
        warnings: const [
          WarningIndicator(
            title: 'Live Call Extortion Alert',
            description: 'Suspicious audio pattern matched known vishing scripts.',
            icon: Icons.warning_amber_rounded,
          ),
        ],
        recommendation: 'Hang up immediately. Do not transfer funds or follow instructions.',
        analysisMethod: AnalysisMethod.localHeuristics,
        originalInput: transcript,
      ),
    );
  }
}
