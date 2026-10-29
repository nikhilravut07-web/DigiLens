import os
import json
import logging
from typing import List, Optional
from fastapi import FastAPI, HTTPException, status, Header
from pydantic import BaseModel, Field
import google.generativeai as genai
from detector import local_heuristic_fallback, local_sms_heuristic_fallback, analyze_url_heuristics
from threat_intel import ThreatIntelligenceService
from benchmark import BenchmarkEvaluator
from dotenv import load_dotenv

if os.path.exists(".env"):
    load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")
if api_key:
    genai.configure(api_key=api_key)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("digilens-backend")

app = FastAPI(
    title="DigiLens AI Scam Detection & Threat Intelligence Backend",
    version="2.0.0",
    description="Backend mediating Google Gemini AI, PhishTank, URLhaus, and benchmark evaluation."
)

threat_intel_service = ThreatIntelligenceService()
benchmark_evaluator = BenchmarkEvaluator()

class TranscriptRequest(BaseModel):
    transcript: str = Field(..., min_length=1, max_length=10000, description="Call conversation transcript")
    claimed_brand: Optional[str] = Field(None, description="Optional claimed organization/bank")
    language: Optional[str] = Field("en-IN", description="Language locale")

class SmsAnalysisRequest(BaseModel):
    sender: Optional[str] = Field(None, description="SMS sender phone number or alphanumeric header")
    body: str = Field(..., min_length=1, max_length=5000, description="SMS text content")
    language: Optional[str] = Field("en-IN", description="Language locale")

class UrlCheckRequest(BaseModel):
    url: str = Field(..., min_length=1, max_length=2000, description="URL to check against threat intelligence")

class WarningIndicatorModel(BaseModel):
    title: str
    description: str
    icon: str = "warning"

class ScamAnalysisResponse(BaseModel):
    risk_level: str = Field(..., description="safe, low, medium, high, or critical")
    risk_score: int = Field(..., ge=0, le=100, description="Numeric risk score 0-100")
    scam_type: str = Field(..., description="digital_arrest, bank_impersonation, otp_theft, remote_access, money_demand, unknown")
    evidence: List[WarningIndicatorModel] = Field(default_factory=list)
    transcript_uncertain: bool = Field(False, description="True if transcript is ambiguous or too short")
    recommended_action: str = Field(...)
    analysis_method: str = Field("ai_gemini")

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "digilens-backend",
        "gemini_configured": bool(api_key),
        "phishtank_configured": bool(os.getenv("PHISHTANK_API_KEY")),
        "urlhaus_configured": bool(os.getenv("URLHAUS_API_KEY"))
    }

@app.post("/api/v1/analyze-voice", response_model=ScamAnalysisResponse)
def analyze_voice(payload: TranscriptRequest):
    if not api_key:
        logger.warning("Gemini API key not configured. Falling back to local heuristics.")
        return local_heuristic_fallback(payload.transcript)

    prompt = f"""
You are an expert cybersecurity AI specialized in detecting phone scams, vishing, digital arrest extortion, bank impersonation, and social engineering in Indian English and global calls.

Analyze the following call transcript contextually:
---
{payload.transcript}
---

Claimed Brand/Context: {payload.claimed_brand or 'None'}
Language: {payload.language}

Rules for Analysis:
1. Distinguish between actual scam demands (e.g. demanding OTP, digital arrest, security deposits) versus legitimate warnings (e.g. "do not share OTP") or normal conversations.
2. Do not flag a call as a scam merely because it mentions money, police, or banks unless there is coercive or fraudulent intent.
3. Return STRICT JSON matching this schema with no markdown formatting around it other than valid JSON:
{{
  "risk_level": "safe" | "low" | "medium" | "high" | "critical",
  "risk_score": <integer 0 to 100>,
  "scam_type": "digital_arrest" | "bank_impersonation" | "otp_theft" | "remote_access" | "money_demand" | "unknown",
  "evidence": [
    {{
      "title": "<short title>",
      "description": "<detailed reason>",
      "icon": "warning"
    }}
  ],
  "transcript_uncertain": <boolean>,
  "recommended_action": "<action advice>"
}}
"""

    models_to_try = ["gemini-3.5-flash", "gemini-flash-latest", "gemini-3.7-flash"]
    response_text = None

    for model_name in models_to_try:
        try:
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(
                prompt,
                generation_config={"temperature": 0.1}
            )
            response_text = response.text
            if response_text:
                logger.info(f"Gemini model {model_name} successfully classified transcript.")
                break
        except Exception as e:
            logger.warning(f"Model {model_name} failed: {e}. Trying next...")
            continue

    if not response_text:
        logger.error("All Gemini models failed or quota exhausted. Falling back to local heuristics.")
        return local_heuristic_fallback(payload.transcript)

    try:
        cleaned = response_text.strip()
        if cleaned.startswith("```json"):
            cleaned = cleaned[7:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        data = json.loads(cleaned.strip())
        data["analysis_method"] = "ai_gemini"
        return data
    except Exception as e:
        logger.error(f"Failed to parse Gemini JSON response: {e}. Raw: {response_text}")
        return local_heuristic_fallback(payload.transcript)

@app.post("/api/v1/analyze-sms", response_model=ScamAnalysisResponse)
def analyze_sms_endpoint(payload: SmsAnalysisRequest):
    if not api_key:
        logger.warning("Gemini API key not configured for SMS. Falling back to local heuristics.")
        return local_sms_heuristic_fallback(payload.body, payload.sender or "")

    prompt = f"""
You are an expert cybersecurity AI specialized in detecting SMS phishing, smishing, bank KYC fraud, advance-fee lotteries, utility disconnection extortion, and credential theft in Indian SMS messages.

Analyze the following incoming SMS text contextually:
---
Sender: {payload.sender or 'Unknown'}
Body: {payload.body}
---

Language: {payload.language}

Rules for Analysis:
1. Contextual discernment: Distinguish actual phishing/smishing links and credential/OTP theft demands from legitimate bank transaction alerts, delivery notifications, or security warnings (e.g., "Do not share your OTP").
2. Do NOT flag an SMS as a scam merely because it mentions a bank, OTP, or electricity unless there is a fraudulent demand, phishing URL, urgency trap, or scam keyword.
3. Return STRICT JSON matching this exact schema with no markdown formatting around it other than valid JSON:
{{
  "risk_level": "safe" | "low" | "medium" | "high" | "critical",
  "risk_score": <integer 0 to 100>,
  "scam_type": "otp_theft" | "fake_kyc" | "utility_threat" | "lottery_scam" | "digital_arrest" | "bank_impersonation" | "unknown",
  "evidence": [
    {{
      "title": "<short title>",
      "description": "<detailed reason>",
      "icon": "warning"
    }}
  ],
  "transcript_uncertain": <boolean>,
  "recommended_action": "<action advice>"
}}
"""

    models_to_try = ["gemini-3.5-flash", "gemini-flash-latest", "gemini-3.7-flash"]
    response_text = None

    for model_name in models_to_try:
        try:
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(
                prompt,
                generation_config={"temperature": 0.1}
            )
            response_text = response.text
            if response_text:
                logger.info(f"Gemini model {model_name} successfully classified SMS.")
                break
        except Exception as e:
            logger.warning(f"SMS model {model_name} failed: {e}. Trying next...")
            continue

    if not response_text:
        logger.error("All Gemini models failed for SMS. Falling back to local SMS heuristics.")
        return local_sms_heuristic_fallback(payload.body, payload.sender or "")

    try:
        cleaned = response_text.strip()
        if cleaned.startswith("```json"):
            cleaned = cleaned[7:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        data = json.loads(cleaned.strip())
        data["analysis_method"] = "ai_gemini"
        return data
    except Exception as e:
        logger.error(f"Failed to parse Gemini SMS JSON: {e}. Raw: {response_text}")
        return local_sms_heuristic_fallback(payload.body, payload.sender or "")

@app.post("/api/v1/threat-intel/check")
async def check_threat_intel(payload: UrlCheckRequest):
    """
    Query PhishTank and URLhaus for verified threat intelligence on a URL.
    """
    result = await threat_intel_service.check_url(payload.url)
    return result

@app.get("/api/v1/benchmark/results")
def get_benchmark_results(threshold: Optional[str] = "medium"):
    """
    Run evaluation benchmark against verified samples in the evaluation dataset using
    the actual DigiLens URL heuristic detector, comparing against independent labels.
    """
    eval_report = benchmark_evaluator.evaluate_detector(
        analyze_url_heuristics,
        risk_threshold=threshold or "medium"
    )
    return eval_report

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
