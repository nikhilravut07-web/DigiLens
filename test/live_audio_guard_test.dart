import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:digilens/services/live_audio_guard_service.dart';
import 'package:digilens/screens/live_call_protection_screen.dart';
import 'package:digilens/services/scan_history_service.dart';
import 'package:digilens/models/scan_result.dart';

class FakeSpeechRecognizer implements ISpeechRecognizer {
  bool available = true;
  bool listening = false;
  stt.SpeechResultListener? resultListener;
  stt.SpeechSoundLevelChange? soundLevelListener;
  stt.SpeechErrorListener? errorListener;
  stt.SpeechStatusListener? statusListener;
  int listenCallCount = 0;
  int stopCallCount = 0;

  @override
  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
    bool debugLogging = false,
  }) async {
    errorListener = onError;
    statusListener = onStatus;
    return available;
  }

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => listening;

  @override
  Future<void> listen({
    required stt.SpeechResultListener onResult,
    stt.SpeechSoundLevelChange? onSoundLevelChange,
    stt.SpeechListenOptions? listenOptions,
  }) async {
    listenCallCount++;
    resultListener = onResult;
    soundLevelListener = onSoundLevelChange;
    listening = true;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    listening = false;
  }

  @override
  Future<void> cancel() async {
    listening = false;
  }

  void emitResult(String words, {required bool isFinal}) {
    resultListener?.call(
      SpeechRecognitionResult(
        [SpeechRecognitionWords(words, null, 1.0)],
        isFinal ? ResultType.finalResult.value : ResultType.partial.value,
      ),
    );
  }

  void emitSoundLevel(double level) {
    soundLevelListener?.call(level);
  }

  void emitError(String errorMsg, {bool permanent = false}) {
    errorListener?.call(SpeechRecognitionError(errorMsg, permanent));
  }

  void emitStatus(String status) {
    statusListener?.call(status);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel permissionChannel =
      MethodChannel('flutter.baseflow.com/permissions/methods');

  late FakeSpeechRecognizer fakeRecognizer;
  final service = LiveAudioGuardService.instance;

  void setupPermissionMock({required int statusResult}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
      if (call.method == 'checkPermissionStatus') {
        return statusResult;
      } else if (call.method == 'requestPermissions') {
        final List<dynamic> permissions = call.arguments as List<dynamic>;
        final Map<int, int> results = {};
        for (final p in permissions) {
          results[p as int] = statusResult;
        }
        return results;
      } else if (call.method == 'openAppSettings') {
        return true;
      }
      return null;
    });
  }

  setUp(() {
    fakeRecognizer = FakeSpeechRecognizer();
    service.setSpeechRecognizerForTesting(fakeRecognizer);
    service.clearTranscript();
    service.stopLiveGuard();
    ScanHistoryService.instance.clearHistory();
    setupPermissionMock(statusResult: 1); // 1 = granted
  });

  // Also clean up service state after each widget test
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
    service.clearTranscript();
    service.stopLiveGuard();
  });

  group('LiveAudioGuardService Pipeline & Recognition Lifecycle', () {
    test('Initial status is idle and clean', () {
      expect(service.status, AudioGuardStatus.idle);
      expect(service.isThreatDetected, isFalse);
      expect(service.liveTranscript, isEmpty);
      expect(service.currentAmplitude, 0.0);
    });

    test('Permission denial sets permissionDenied status', () async {
      setupPermissionMock(statusResult: 0); // 0 = denied
      final granted = await service.requestMicrophonePermission();

      expect(granted, isFalse);
      expect(service.status, AudioGuardStatus.permissionDenied);
      expect(service.statusMessage, contains('denied'));
    });

    test('Permission permanently denied sets permissionPermanentlyDenied status', () async {
      setupPermissionMock(statusResult: 4); // 4 = permanentlyDenied
      final granted = await service.requestMicrophonePermission();

      expect(granted, isFalse);
      expect(service.status, AudioGuardStatus.permissionPermanentlyDenied);
      expect(service.statusMessage, contains('permanently denied'));
    });

    test('Speech recognition unavailable sets unavailable status', () async {
      fakeRecognizer.available = false;

      await service.startLiveGuard();
      expect(service.status, AudioGuardStatus.unavailable);
      expect(service.statusMessage, contains('unavailable'));
    });

    test('Start live guard starts recognition when permission granted', () async {
      await service.startLiveGuard();

      expect(service.status, AudioGuardStatus.listening);
      expect(fakeRecognizer.listening, isTrue);
      expect(fakeRecognizer.listenCallCount, 1);
      expect(service.statusMessage, contains('Listening'));
    });

    test('Receives partial and final speech results correctly', () async {
      await service.startLiveGuard();

      // Partial result
      fakeRecognizer.emitResult('hello this is', isFinal: false);
      expect(service.liveTranscript, 'hello this is');

      // Another partial result
      fakeRecognizer.emitResult('hello this is officer', isFinal: false);
      expect(service.liveTranscript, 'hello this is officer');

      // Final result for first utterance
      fakeRecognizer.emitResult('hello this is officer sharma', isFinal: true);
      expect(service.liveTranscript, 'hello this is officer sharma');

      // Second utterance partial
      fakeRecognizer.emitResult('how can I help', isFinal: false);
      expect(service.liveTranscript, 'hello this is officer sharma how can I help');

      // Second utterance final
      fakeRecognizer.emitResult('how can I help you today', isFinal: true);
      expect(service.liveTranscript, 'hello this is officer sharma how can I help you today');
    });

    test('Empty speech results are ignored and do not alter transcript', () async {
      await service.startLiveGuard();

      fakeRecognizer.emitResult('Testing input', isFinal: true);
      expect(service.liveTranscript, 'Testing input');

      fakeRecognizer.emitResult('', isFinal: false);
      fakeRecognizer.emitResult('   ', isFinal: true);
      expect(service.liveTranscript, 'Testing input');
    });

    test('Duplicate chunks are prevented from repeating in transcript', () async {
      await service.startLiveGuard();

      fakeRecognizer.emitResult('Repeat phrase', isFinal: true);
      expect(service.liveTranscript, 'Repeat phrase');

      // Re-emitting the same final phrase
      fakeRecognizer.emitResult('Repeat phrase', isFinal: true);
      expect(service.liveTranscript, 'Repeat phrase');
    });

    test('Sound level updates amplitude clamped between 0 and 1', () async {
      await service.startLiveGuard();

      fakeRecognizer.emitSoundLevel(5.0);
      expect(service.currentAmplitude, greaterThan(0.0));
      expect(service.currentAmplitude, lessThanOrEqualTo(1.0));

      fakeRecognizer.emitSoundLevel(-30.0);
      expect(service.currentAmplitude, 0.0);
    });

    test('Scam phrases trigger VoiceAnalysisService threat detection and history', () async {
      await service.startLiveGuard();

      // Emit ordinary greeting - should not trigger threat
      fakeRecognizer.emitResult('Good morning, how are you doing today?', isFinal: true);
      await Future.delayed(const Duration(milliseconds: 700));
      expect(service.isThreatDetected, isFalse);

      // Emit scam extortion phrase
      fakeRecognizer.emitResult(
        'You are under digital arrest. Transfer 1 Lakh immediately to clear your name.',
        isFinal: true,
      );
      await Future.delayed(const Duration(milliseconds: 700));

      expect(service.isThreatDetected, isTrue);
      expect(service.lastAlertTitle, isNotNull);
      expect(service.statusMessage, contains('ALERT'));

      // Check scan history recorded
      final history = ScanHistoryService.instance.items;
      expect(history.isNotEmpty, isTrue);
      expect(history.first.result.type, ScanType.voice);
      expect(history.first.result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
    });

    test('Recognition errors (timeout/no_match) do not crash service', () async {
      await service.startLiveGuard();

      fakeRecognizer.emitError('error_speech_timeout');
      expect(service.status, AudioGuardStatus.listening);

      fakeRecognizer.emitError('error_no_match');
      expect(service.status, AudioGuardStatus.listening);
    });

    test('Stop live guard releases recognition and pauses listening', () async {
      await service.startLiveGuard();
      expect(service.status, AudioGuardStatus.listening);

      await service.stopLiveGuard();
      expect(service.status, AudioGuardStatus.idle);
      expect(fakeRecognizer.listening, isFalse);
      expect(service.currentAmplitude, 0.0);
      expect(service.statusMessage, contains('paused'));
    });

    test('Clear transcript resets transcript and threat flags', () async {
      service.simulateThreatDetection('Test Threat', 'Simulated text');
      expect(service.isThreatDetected, isTrue);
      expect(service.liveTranscript, 'Simulated text');

      service.clearTranscript();
      expect(service.isThreatDetected, isFalse);
      expect(service.lastAlertTitle, isNull);
      expect(service.liveTranscript, isEmpty);
    });
  });

  group('LiveCallProtectionScreen Widget Tests', () {
    testWidgets('Renders Live Call Protection screen and disclaimers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiveCallProtectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Call Protection & Guard'), findsOneWidget);
      expect(find.text('RECORD_AUDIO Permission'), findsOneWidget);
      expect(find.text('Start Live Audio Guard'), findsOneWidget);
      expect(find.text('Important Android Call Audio Limitation'), findsOneWidget);
      expect(find.textContaining('Why speakerphone is needed'), findsOneWidget);
    });

    testWidgets('Tapping Start Live Audio Guard starts real recognition and shows transcript card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiveCallProtectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.text('Start Live Audio Guard');
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(service.status, AudioGuardStatus.listening);
      expect(find.text('Live Guard Active'), findsOneWidget);
      expect(find.text('Stop Live Audio Guard'), findsOneWidget);
      expect(find.text('Real-Time Speech Transcript'), findsOneWidget);
      expect(find.text('Listening to speech...'), findsOneWidget);

      // Emit recognized words from recognizer
      fakeRecognizer.emitResult('Hello from device microphone', isFinal: false);
      await tester.pump();

      expect(find.text('Hello from device microphone'), findsOneWidget);

      // Tap stop using finder specifically for the stop button inside the permission card or bottom
      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop Live Audio Guard'));
      await tester.pumpAndSettle();
      expect(service.status, AudioGuardStatus.idle);
      expect(find.text('Start Live Audio Guard'), findsOneWidget);
    });

    testWidgets('Testing mode simulation works and triggers alert popup and banner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiveCallProtectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final simButton = find.text('Simulate Digital Arrest Threat');
      expect(simButton, findsOneWidget);

      await tester.tap(simButton);
      await tester.pumpAndSettle();

      expect(service.isThreatDetected, isTrue);
      // Verify AlertDialog popup is shown
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Digital Arrest Extortion Detected'), findsWidgets);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Stop monitoring'), findsOneWidget);

      // Tap dismiss
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Normal speech produces no scam popup or threat flag', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiveCallProtectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await service.startLiveGuard();
      fakeRecognizer.emitResult('Hello friend, how is the weather today?', isFinal: true);
      await tester.pumpAndSettle();

      expect(service.isThreatDetected, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Partial transcript updates do not produce duplicate popups', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiveCallProtectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await service.startLiveGuard();
      fakeRecognizer.emitResult('CBI officer speaking', isFinal: false);
      await tester.pumpAndSettle();
      fakeRecognizer.emitResult('CBI officer speaking. You are under digital arrest. Transfer 1 Lakh.', isFinal: true);
      await tester.pumpAndSettle();

      // Exactly one AlertDialog should be shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // Re-emitting the same threat phrase should not trigger duplicate popup
      fakeRecognizer.emitResult('CBI officer speaking. You are under digital arrest. Transfer 1 Lakh.', isFinal: true);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('New scam event triggers a new popup after previous is dismissed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiveCallProtectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // First scam event
      service.simulateThreatDetection('Digital Arrest Extortion Detected', 'CBI officer speaking.');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // Clear transcript / reset state for new threat
      service.clearTranscript();
      await tester.pumpAndSettle();

      // Second distinct scam event
      service.simulateThreatDetection('Bank Impersonation & OTP Theft', 'This is SBI branch manager. Tell me your OTP.');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Bank Impersonation & OTP Theft'), findsWidgets);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
    });
  });
}
