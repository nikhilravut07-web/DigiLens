import pytest
from fastapi.testclient import TestClient
from main import app, local_heuristic_fallback

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "digilens-backend"
    assert "gemini_configured" in data

def test_local_heuristic_digital_arrest():
    res = local_heuristic_fallback("You are under digital arrest by CBI officer. Send money now.")
    assert res["risk_level"] in ["high", "critical"]
    assert res["scam_type"] == "digital_arrest"
    assert len(res["evidence"]) > 0

def test_local_heuristic_benign():
    res = local_heuristic_fallback("Hello, let's meet tomorrow at 10 AM for coffee.")
    assert res["risk_level"] == "safe"
    assert res["scam_type"] == "unknown"
    assert len(res["evidence"]) == 0

def test_analyze_voice_endpoint_fallback():
    response = client.post("/api/v1/analyze-voice", json={
        "transcript": "Officer from police cyber cell. Install AnyDesk right now.",
        "language": "en-IN"
    })
    assert response.status_code == 200
    data = response.json()
    assert data["risk_level"] in ["medium", "high", "critical"]
    assert len(data["evidence"]) >= 1
    assert "analysis_method" in data

def test_empty_transcript_validation():
    response = client.post("/api/v1/analyze-voice", json={
        "transcript": ""
    })
    assert response.status_code == 422  # Unprocessable Entity

def test_analyze_sms_endpoint_fallback():
    response = client.post("/api/v1/analyze-sms", json={
        "sender": "AX-SBIBNK",
        "body": "Dear customer, your SBI account is blocked due to KYC. Click http://sbi-update.xyz",
        "language": "en-IN"
    })
    assert response.status_code == 200
    data = response.json()
    assert data["risk_level"] in ["high", "critical"]
    assert len(data["evidence"]) >= 1
    assert "analysis_method" in data

