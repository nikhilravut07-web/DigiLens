import 'package:flutter_test/flutter_test.dart';
import 'package:digilens/services/performance_metrics_service.dart';

void main() {
  group('PerformanceMetricsService Tests', () {
    test('calculatePrecision returns correct ratio and handles zero denominator', () {
      final service = PerformanceMetricsService.instance;

      // TP = 8, FP = 2 -> 8 / 10 = 0.8
      expect(service.calculatePrecision(tp: 8, fp: 2), 0.8);

      // TP = 0, FP = 0 -> 0.0 (no division by zero)
      expect(service.calculatePrecision(tp: 0, fp: 0), 0.0);
    });

    test('calculateRecall returns correct ratio and handles zero denominator', () {
      final service = PerformanceMetricsService.instance;

      // TP = 7, FN = 3 -> 7 / 10 = 0.7
      expect(service.calculateRecall(tp: 7, fn: 3), 0.7);

      // TP = 0, FN = 0 -> 0.0
      expect(service.calculateRecall(tp: 0, fn: 0), 0.0);
    });

    test('calculateF1 computes harmonic mean correctly', () {
      final service = PerformanceMetricsService.instance;

      final precision = 0.8;
      final recall = 0.7;
      // 2 * (0.8 * 0.7) / (0.8 + 0.7) = 1.12 / 1.5 = 0.746666...
      final f1 = service.calculateF1(precision: precision, recall: recall);
      expect(f1, closeTo(0.7466, 0.001));

      expect(service.calculateF1(precision: 0.0, recall: 0.0), 0.0);
    });

    test('calculateAccuracy computes overall accuracy correctly', () {
      final service = PerformanceMetricsService.instance;

      // TP = 10, TN = 10, FP = 5, FN = 5 -> Total = 30, Correct = 20 -> 20/30 = 0.6666...
      final acc = service.calculateAccuracy(tp: 10, tn: 10, fp: 5, fn: 5);
      expect(acc, closeTo(0.6666, 0.001));

      expect(service.calculateAccuracy(tp: 0, tn: 0, fp: 0, fn: 0), 0.0);
    });
  });
}
