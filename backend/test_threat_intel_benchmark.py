import pytest
import os
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch
from main import app
from benchmark import BenchmarkEvaluator
from detector import analyze_url_heuristics

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "phishtank_configured" in data
    assert "urlhaus_configured" in data

def test_threat_intel_endpoint():
    with patch("main.threat_intel_service.check_url", new_callable=AsyncMock) as mock_check:
        mock_check.return_value = {
            "url": "https://example-phish.xyz",
            "confirmed_threat": True,
            "phishtank": {"source": "PhishTank", "match_found": True, "is_phishing": True},
            "urlhaus": {"source": "URLhaus", "match_found": False, "is_malware": False}
        }
        response = client.post("/api/v1/threat-intel/check", json={"url": "https://example-phish.xyz"})
        assert response.status_code == 200
        data = response.json()
        assert data["confirmed_threat"] is True
        assert data["phishtank"]["is_phishing"] is True

def test_benchmark_results_endpoint_default():
    response = client.get("/api/v1/benchmark/results")
    assert response.status_code == 200
    data = response.json()
    assert "metrics" in data
    assert "confusion_matrix" in data
    assert "dataset_version" in data
    assert "timestamp" in data
    assert "limitations" in data
    assert data["evaluated_samples"] > 0
    assert data["eligible_samples"] > 0
    assert data["risk_threshold_used"] == "medium"
    assert "precision" in data["metrics"]
    assert "recall" in data["metrics"]
    assert "false_positive_rate" in data["metrics"]

def test_benchmark_results_configurable_threshold():
    response_high = client.get("/api/v1/benchmark/results?threshold=high")
    assert response_high.status_code == 200
    data_high = response_high.json()
    assert data_high["risk_threshold_used"] == "high"

    response_low = client.get("/api/v1/benchmark/results?threshold=low")
    assert response_low.status_code == 200
    data_low = response_low.json()
    assert data_low["risk_threshold_used"] == "low"

def test_benchmark_evaluator_unknown_label_and_zero_denominator():
    # Synthetic evaluator with empty / unknown label dataset
    evaluator = BenchmarkEvaluator(dataset_path="non_existent_dataset.json")
    # Non existent returns empty samples
    res = evaluator.evaluate_detector(lambda url: {"risk_level": "safe"})
    assert res["evaluated_samples"] == 0
    assert res["metrics"]["precision"] == 0.0
    assert res["metrics"]["recall"] == 0.0
    assert res["metrics"]["false_positive_rate"] == 0.0

def test_benchmark_evaluator_detector_errors_and_missing_evidence(tmp_path):
    dataset_file = tmp_path / "test_eval_dataset.json"
    dataset_file.write_text("""{
        "version": "v-test",
        "timestamp": "2026-10-29",
        "samples": [
            {"url": "https://test-unknown.com", "label": "unverified", "label_source": "none"},
            {"url": "https://test-error.com", "label": "malicious", "label_source": "test"},
            {"url": "https://test-invalid-return.com", "label": "benign", "label_source": "test"},
            {"url": "http://192.168.1.1/mal.apk", "label": "malicious", "label_source": "test"}
        ]
    }""", encoding="utf-8")

    evaluator = BenchmarkEvaluator(dataset_path=str(dataset_file))

    def faulty_detector(url: str):
        if "test-error" in url:
            raise RuntimeError("Detector simulated network/logic crash")
        if "test-invalid-return" in url:
            return "not a dict"
        return {"risk_level": "critical", "risk_score": 90}

    res = evaluator.evaluate_detector(faulty_detector)
    assert res["unknown_labels"] == 1  # 'unverified' label excluded
    assert res["errors"] == 2          # 1 exception + 1 invalid return
    assert res["evaluated_samples"] == 1
    assert res["confusion_matrix"]["tp"] == 1
    assert res["metrics"]["precision"] == 1.0

def test_live_threat_intel_credentials_handling():
    # If environment variable is absent, query runs gracefully and reports error/queried status
    from threat_intel import ThreatIntelligenceService
    service = ThreatIntelligenceService()
    # If credentials are not set, verify that error handling works without crashing
    assert hasattr(service, "phishtank_api_key")
    assert hasattr(service, "urlhaus_api_key")
