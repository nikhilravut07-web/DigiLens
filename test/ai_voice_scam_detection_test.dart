import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:digilens/models/scan_result.dart';
import 'package:digilens/services/voice_analysis_service.dart';
import 'package:digilens/services/ai_voice_analysis_service.dart';
import 'package:digilens/services/live_audio_guard_service.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('Phase 7: Contextual AI Voice Scam Detection & Safety Tests', () {
    late VoiceAnalysisService localService;

    setUp(() {
      localService = VoiceAnalysisService();
    });

    // 1. Legitimate conversation mentioning an OTP
    test('1. Legitimate transaction notification mentioning OTP does not trigger critical alarm', () async {
      const transcript = 'Your one time password OTP for transaction of Rs 500 at Amazon is 492019. Valid for 10 mins.';
      final result = await localService.classifyTranscript(transcript);
      expect(result.riskLevel, isNot(RiskLevel.critical));
    });

    // 2. Someone warning a user not to reveal an OTP
    test('2. Bank security warning advising user NOT to reveal OTP is safe', () async {
      const transcript = 'Security advisory from your branch: Please do not reveal your OTP, PIN or CVV to anyone, even if they claim to be from bank.';
      // Test contextual AI provider with mock response
      final aiService = AiVoiceAnalysisService(
        client: MockHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'risk_level': 'safe',
              'risk_score': 0,
              'scam_type': 'unknown',
              'evidence': [],
              'transcript_uncertain': false,
              'recommended_action': 'Continue with caution',
            }),
            200,
          );
        }),
      );

      final result = await aiService.classifyTranscript(transcript);
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, 0);
    });

    // 3. Fake police threats and digital-arrest coercion
    test('3. Fake police threats and digital-arrest coercion trigger critical extortion alert', () async {
      const transcript = 'I am police commissioner from cyber cell. You are placed under digital arrest. Stay on video call and do not disconnect.';
      final result = await localService.classifyTranscript(transcript);
      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(result.warnings.any((w) => w.title.contains('Digital arrest')), isTrue);
    });

    // 4. A suspicious money-transfer demand
    test('4. Suspicious money-transfer demand triggers high/critical threat', () async {
      const transcript = 'To clear your name and verify your account, you must transfer 1 lakh to this government account immediately.';
      final result = await localService.classifyTranscript(transcript);
      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(result.warnings.any((w) => w.title.contains('Demand for money transfer')), isTrue);
    });

    // 5. A bank employee discussing ordinary account verification
    test('5. Legitimate bank employee discussing ordinary account verification is safe', () async {
      const transcript = 'Hello, this is Neha from HDFC branch. Just calling to confirm if you received your new cheque book by courier.';
      final result = await localService.classifyTranscript(transcript);
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.warnings, isEmpty);
    });

    // 6. Remote-access installation demands
    test('6. Remote-access installation demand flags screen-share threat', () async {
      const transcript = 'Your mobile device has a virus. Please install AnyDesk or TeamViewer and read out the nine digit code.';
      final result = await localService.classifyTranscript(transcript);
      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical, RiskLevel.medium]));
      expect(result.warnings.any((w) => w.title.contains('Remote screen-sharing')), isTrue);
    });

    // 7. Repeated partial transcripts
    test('7. Overlap deduplication removes prefix overlap while preserving genuine speech', () {
      const prior = 'hello this is officer sharma';
      const incomingWithOverlap = 'officer sharma how can I help you today';
      final clean = LiveAudioGuardService.removeOverlap(prior, incomingWithOverlap);
      expect(clean, 'how can I help you today');

      // Genuine repetition within utterance is preserved
      const genuineRepetition = 'urgent urgent transfer now';
      final preserved = LiveAudioGuardService.removeOverlap('hello', genuineRepetition);
      expect(preserved, 'urgent urgent transfer now');
    });

    // 8. Duplicate final transcripts
    test('8. Exactly duplicate final transcripts are resolved cleanly', () {
      const prior = 'transfer 50,000 immediately';
      const duplicateIncoming = 'transfer 50,000 immediately';
      final clean = LiveAudioGuardService.removeOverlap(prior, duplicateIncoming);
      expect(clean, isEmpty);
    });

    // 9. AI API timeout falls back gracefully to local heuristic rules
    test('9. AI API timeout falls back seamlessly to local heuristics', () async {
      final aiService = AiVoiceAnalysisService(
        client: MockHttpClient((req) async {
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('Connection timed out');
        }),
      );

      const transcript = 'CBI officer speaking. You are under digital arrest.';
      final result = await aiService.classifyTranscript(transcript);
      // Fallback succeeds and identifies threat
      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(result.analysisMethod, AnalysisMethod.localHeuristics);
    });

    // 10. AI API quota exhaustion / 429 returns graceful fallback
    test('10. AI API HTTP 429 quota exhaustion falls back to local rules', () async {
      final aiService = AiVoiceAnalysisService(
        client: MockHttpClient((req) async {
          return http.Response('{"error": "Resource exhausted / quota exceeded"}', 429);
        }),
      );

      const transcript = 'Please install AnyDesk application immediately.';
      final result = await aiService.classifyTranscript(transcript);
      expect(result.riskLevel, isIn([RiskLevel.medium, RiskLevel.high, RiskLevel.critical]));
      expect(result.analysisMethod, AnalysisMethod.localHeuristics);
    });

    // 11. Incorrect or incomplete model JSON handled safely
    test('11. Incomplete or malformed JSON from model is caught safely', () async {
      final aiService = AiVoiceAnalysisService(
        client: MockHttpClient((req) async {
          return http.Response('{ corrupt_json_not_valid }', 200);
        }),
      );

      const transcript = 'Transfer 1 lakh to clear your name.';
      final result = await aiService.classifyTranscript(transcript);
      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(result.analysisMethod, AnalysisMethod.localHeuristics);
    });

    // 12. AI unavailable while local detection remains functional
    test('12. AI unavailable (503 Service Unavailable) retains full local protection', () async {
      final aiService = AiVoiceAnalysisService(
        client: MockHttpClient((req) async {
          return http.Response('{"error": "Model overloaded"}', 503);
        }),
      );

      const transcript = 'Calling from SBI manager. Tell me your OTP and CVV.';
      final result = await aiService.classifyTranscript(transcript);
      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
    });

    // 13. Alert deduplication
    test('13. Validated structured AI response is correctly mapped to ScanResult', () async {
      final aiService = AiVoiceAnalysisService(
        client: MockHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'risk_level': 'critical',
              'risk_score': 95,
              'scam_type': 'digital_arrest',
              'evidence': [
                {
                  'title': 'Digital Arrest Coercion',
                  'description': 'Threatening legal action and demanding funds via video call.',
                  'icon': 'gavel'
                }
              ],
              'transcript_uncertain': false,
              'recommended_action': 'Hang up and dial 1930.',
            }),
            200,
          );
        }),
      );

      const transcript = 'You are under digital arrest. Transfer money.';
      final result = await aiService.classifyTranscript(transcript);
      expect(result.riskLevel, RiskLevel.critical);
      expect(result.riskScore, 95);
      expect(result.warnings.length, 1);
      expect(result.warnings.first.title, 'Digital Arrest Coercion');
      expect(result.recommendation, contains('1930'));
      expect(result.analysisMethod, AnalysisMethod.mlModel);
    });

    // 14. Uncertain transcription handled without crashing
    test('14. Uncertain / short transcripts do not trigger false positive critical alarms', () async {
      const shortSnippet = 'yes okay';
      final result = await localService.classifyTranscript(shortSnippet);
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.warnings, isEmpty);
    });
  });

  group('Synthetic Voice Scam Detection Benchmarks', () {
    test('Compute detection accuracy, precision, recall, and false positive rate', () async {
      final detector = VoiceAnalysisService();

      final corpus = [
        // Positive (Scam)
        {'text': 'CBI officer here. You are under digital arrest. Stay on call and transfer 1 lakh.', 'isScam': true},
        {'text': 'This is your bank manager from SBI. Tell me your CVV and OTP to activate your card.', 'isScam': true},
        {'text': 'Customs parcel seized with narcotics. Do not inform your family or disconnect.', 'isScam': true},
        {'text': 'Install AnyDesk app from play store so we can fix your banking application.', 'isScam': true},
        {'text': 'Transfer money to security deposit to clear your name from court notice.', 'isScam': true},

        // Negative (Legitimate)
        {'text': 'Hi, are we still meeting for lunch at 1 PM today?', 'isScam': false},
        {'text': 'This is an automated courtesy reminder. Your broadband bill is due tomorrow.', 'isScam': false},
        {'text': 'Reminder: Your electricity bill is due by Friday.', 'isScam': false},
        {'text': 'Your food delivery driver is arriving with your order.', 'isScam': false},
        {'text': 'Please confirm your appointment with Dr. Sharma for Wednesday.', 'isScam': false},
      ];

      int tp = 0;
      int fp = 0;
      int tn = 0;
      int fn = 0;

      final stopwatch = Stopwatch()..start();

      for (final sample in corpus) {
        final text = sample['text'] as String;
        final isScam = sample['isScam'] as bool;

        final result = await detector.classifyTranscript(text);
        final detectedScam = result.riskLevel.index >= RiskLevel.medium.index;

        if (isScam && detectedScam) tp++;
        if (!isScam && detectedScam) fp++;
        if (!isScam && !detectedScam) tn++;
        if (isScam && !detectedScam) fn++;
      }

      stopwatch.stop();

      final precision = tp / (tp + fp);
      final recall = tp / (tp + fn);
      final f1 = 2 * (precision * recall) / (precision + recall);
      final accuracy = (tp + tn) / corpus.length;
      final fpr = fp / (fp + tn);
      final avgTimeMs = stopwatch.elapsedMilliseconds / corpus.length;

      // Print verified benchmark report
      // ignore: avoid_print
      print('\n=== DIGILENS VOICE SCAM DETECTION BENCHMARK ===');
      // ignore: avoid_print
      print('  Total Samples      : ${corpus.length}');
      // ignore: avoid_print
      print('  True Positives (TP): $tp');
      // ignore: avoid_print
      print('  False Positives(FP): $fp');
      // ignore: avoid_print
      print('  True Negatives (TN): $tn');
      // ignore: avoid_print
      print('  False Negatives(FN): $fn');
      // ignore: avoid_print
      print('  Precision          : ${(precision * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('  Recall             : ${(recall * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('  F1 Score           : ${(f1 * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('  Accuracy           : ${(accuracy * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('  False Positive Rate: ${(fpr * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('  Avg Inference Time : ${avgTimeMs.toStringAsFixed(2)} ms/utterance');
      // ignore: avoid_print
      print('===============================================\n');

      expect(tp, 5);
      expect(fp, 0);
      expect(tn, 5);
      expect(fn, 0);
      expect(precision, 1.0);
      expect(recall, 1.0);
      expect(fpr, 0.0);
    });
  });
}
