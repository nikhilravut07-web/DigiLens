import json
import os
from typing import List, Dict, Any, Callable

class BenchmarkEvaluator:
    def __init__(self, dataset_path: str = None):
        if dataset_path is None:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            self.dataset_path = os.path.join(base_dir, "evaluation_dataset.json")
        else:
            self.dataset_path = dataset_path

    def load_dataset(self) -> Dict[str, Any]:
        if not os.path.exists(self.dataset_path):
            return {"version": "v2.0", "samples": [], "unverified_sandbox": [], "limitations": ""}
        with open(self.dataset_path, "r", encoding="utf-8") as f:
            return json.load(f)

    def evaluate_detector(self, detector_func: Callable[[str], Dict[str, Any]], risk_threshold: str = "medium") -> Dict[str, Any]:
        """
        Evaluates detector_func against rigorously verified samples in the dataset.

        Args:
            detector_func: Callable taking a URL string and returning dict with 'risk_level' and optional 'risk_score'.
            risk_threshold: Threshold level to trigger positive classification ('low', 'medium', 'high', 'critical').
                           Default is 'medium' (risk levels >= medium are classified as malicious positive).
        """
        dataset = self.load_dataset()
        samples = dataset.get("samples", [])

        # Risk level rank mapping for configurable threshold
        risk_ranks = {
            "safe": 0,
            "low": 1,
            "medium": 2,
            "high": 3,
            "critical": 4
        }
        threshold_rank = risk_ranks.get(risk_threshold.lower(), 2)

        tp = 0
        fp = 0
        tn = 0
        fn = 0
        errors = 0
        unknown_labels = 0
        evaluated_results = []

        for sample in samples:
            url = sample.get("url")
            ground_truth = sample.get("label", "unknown").lower()
            label_type = sample.get("label_type", "unknown")

            # Rule 3: If a URL cannot be verified or has unknown/unsupported label, mark unknown and exclude
            if ground_truth not in ["malicious", "benign"]:
                unknown_labels += 1
                evaluated_results.append({
                    "url": url,
                    "ground_truth": ground_truth,
                    "status": "excluded_unknown_label",
                    "reason": f"Label '{ground_truth}' is not binary malicious/benign."
                })
                continue

            try:
                # Rule 6: Run detector independently
                prediction_res = detector_func(url)
                if not isinstance(prediction_res, dict) or "risk_level" not in prediction_res:
                    errors += 1
                    evaluated_results.append({
                        "url": url,
                        "ground_truth": ground_truth,
                        "status": "detector_error",
                        "reason": "Detector returned invalid or missing risk_level."
                    })
                    continue

                risk_level = prediction_res.get("risk_level", "safe").lower()
                predicted_rank = risk_ranks.get(risk_level, 0)

                # Binary mapping based on configurable threshold
                predicted_positive = predicted_rank >= threshold_rank
                actual_positive = (ground_truth == "malicious")

                if actual_positive and predicted_positive:
                    tp += 1
                    outcome = "TP"
                elif not actual_positive and predicted_positive:
                    fp += 1
                    outcome = "FP"
                elif not actual_positive and not predicted_positive:
                    tn += 1
                    outcome = "TN"
                else:
                    fn += 1
                    outcome = "FN"

                evaluated_results.append({
                    "url": url,
                    "ground_truth": ground_truth,
                    "label_type": label_type,
                    "label_source": sample.get("label_source", "Unknown"),
                    "predicted_risk": risk_level,
                    "outcome": outcome
                })
            except Exception as e:
                errors += 1
                evaluated_results.append({
                    "url": url,
                    "ground_truth": ground_truth,
                    "status": "detector_exception",
                    "reason": str(e)
                })

        total_evaluated = tp + tn + fp + fn

        # Rule 8: Handle zero denominators gracefully
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        specificity = tn / (tn + fp) if (tn + fp) > 0 else 0.0
        f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0
        accuracy = (tp + tn) / total_evaluated if total_evaluated > 0 else 0.0
        fpr = fp / (fp + tn) if (fp + tn) > 0 else 0.0

        return {
            "dataset_version": dataset.get("version", "v2.0"),
            "timestamp": dataset.get("timestamp", "2026-10-29"),
            "total_dataset_samples": len(samples) + len(dataset.get("unverified_sandbox", [])),
            "eligible_samples": len(samples),
            "evaluated_samples": total_evaluated,
            "errors": errors,
            "unknown_labels": unknown_labels,
            "risk_threshold_used": risk_threshold.lower(),
            "limitations": dataset.get("limitations", ""),
            "confusion_matrix": {
                "tp": tp,
                "fp": fp,
                "tn": tn,
                "fn": fn
            },
            "metrics": {
                "precision": round(precision, 4),
                "recall": round(recall, 4),
                "specificity": round(specificity, 4),
                "f1_score": round(f1, 4),
                "accuracy": round(accuracy, 4),
                "false_positive_rate": round(fpr, 4)
            },
            "results": evaluated_results
        }
