class PerformanceMetricsService {
  static final PerformanceMetricsService instance = PerformanceMetricsService._internal();
  PerformanceMetricsService._internal();

  /// Calculates Precision: TP / (TP + FP)
  /// Of the items classified as fraudulent, what proportion were actually fraudulent?
  double calculatePrecision({required int tp, required int fp}) {
    if ((tp + fp) <= 0) return 0.0;
    return tp / (tp + fp);
  }

  /// Calculates Recall (and Fraud Detection Rate): TP / (TP + FN)
  /// Of all actually fraudulent items, what proportion did DigiLens correctly detect?
  double calculateRecall({required int tp, required int fn}) {
    if ((tp + fn) <= 0) return 0.0;
    return tp / (tp + fn);
  }

  /// Calculates F1 Score: 2 * (Precision * Recall) / (Precision + Recall)
  double calculateF1({required double precision, required double recall}) {
    if ((precision + recall) <= 0) return 0.0;
    return 2 * (precision * recall) / (precision + recall);
  }

  /// Calculates Accuracy: (TP + TN) / (TP + TN + FP + FN)
  double calculateAccuracy({
    required int tp,
    required int tn,
    required int fp,
    required int fn,
  }) {
    final total = tp + tn + fp + fn;
    if (total <= 0) return 0.0;
    return (tp + tn) / total;
  }
}
