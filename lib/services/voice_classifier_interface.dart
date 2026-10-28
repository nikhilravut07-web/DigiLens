import 'package:digilens/models/scan_result.dart';

/// Minimal, honest contract for any text or transcript scam classifier.
///
/// This interface allows future on-device ML models (e.g. TFLite, ONNX,
/// or federated learning client updates) to be plugged in interchangeably
/// with rule-based heuristics without modifying screen code.
///
/// NOTE ON FEDERATED LEARNING:
/// A true federated learning client requires:
/// 1. Local training step: compute gradient updates on on-device user data.
/// 2. Privacy mechanism: differential privacy noise addition or secure aggregation.
/// 3. Communication: upload model weights (never user data) to an aggregation server.
/// 4. Model distribution: download aggregated global model weights.
/// This interface represents the *inference* consumer of such a trained model.
abstract class VoiceTranscriptClassifier {
  /// Name or identifier of this classifier implementation (e.g. "Rule-based Heuristics v1.0").
  String get name;

  /// Whether this classifier uses a trained machine learning model or rule heuristics.
  AnalysisMethod get method;

  /// Evaluates a text transcript of a voice call and returns a [ScanResult].
  Future<ScanResult> classifyTranscript(String transcript);
}
