"""
Live smoke test for Gemini API and contextual scam detection.
"""
import os
import json
from dotenv import load_dotenv
import google.generativeai as genai

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")

def extract_response_text(res) -> str:
    if not res:
        return ""
    try:
        return res.text
    except Exception:
        pass
    try:
        if res.candidates and res.candidates[0].content and res.candidates[0].content.parts:
            parts = [p.text for p in res.candidates[0].content.parts if hasattr(p, "text") and p.text]
            return "".join(parts)
    except Exception:
        pass
    return ""

def run_smoke_test():
    if not api_key:
        print("GEMINI_API_KEY is not set in backend/.env")
        return False

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-3.5-flash")

    test_cases = [
        {
            "phrase": "You are under digital arrest. I am from CBI.",
            "expect_scam": True,
            "expected_scam_type": "digital_arrest",
        },
        {
            "phrase": "This is a police officer. A case has been registered against you. Transfer money to avoid arrest.",
            "expect_scam": True,
            "expected_scam_type": "digital_arrest",
        },
        {
            "phrase": "I am calling from your bank. Install AnyDesk so I can verify your account.",
            "expect_scam": True,
            "expected_scam_type": "remote_access",
        },
        {
            "phrase": "Never share your OTP with anyone, including bank employees.",
            "expect_scam": False,
            "expected_scam_type": "unknown",
        },
        {
            "phrase": "I am a police officer calling to confirm a public event.",
            "expect_scam": False,
            "expected_scam_type": "unknown",
        },
    ]

    prompt_template = """You are an expert cybersecurity AI specialized in detecting phone scams, vishing, digital arrest extortion, bank impersonation, and social engineering in Indian English and global calls.

Analyze the following call transcript contextually:
---
{transcript}
---

Claimed Brand/Context: None
Language: en-IN

Rules for Analysis:
1. Contextual discernment: Distinguish actual scam demands and coercion (e.g. demanding money, claiming fake 'digital arrest', asking to install remote access apps like AnyDesk, demanding OTP/PIN/credentials) from legitimate warnings (e.g. 'Never share your OTP') or legitimate inquiries (e.g. a police officer confirming a public event, a bank representative asking about a cheque book).
2. Do NOT flag a call as a scam merely because words like 'police', 'CBI', 'bank', or 'OTP' appear. Only flag when there is fraudulent, coercive, or extractive intent.
3. If the transcript is legitimate safety advice, normal inquiry, or non-threatening, set risk_level to 'safe' or 'low', risk_score to <= 20, scam_type to 'unknown', and empty evidence.
4. If the transcript represents a known scam pattern (such as digital arrest extortion, remote access takeover, fake case registration), classify it accurately with appropriate risk_level ('high' or 'critical'), risk_score (>= 70), and specific evidence.
5. Return STRICT JSON with this exact schema and no markdown formatting:
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
}}"""

    all_passed = True
    for case in test_cases:
        p = prompt_template.format(transcript=case["phrase"])
        res = model.generate_content(p, generation_config={"temperature": 0.1})
        raw = extract_response_text(res).strip()
        if raw.startswith("```json"):
            raw = raw[7:]
        elif raw.startswith("```"):
            raw = raw[3:]
        if raw.endswith("```"):
            raw = raw[:-3]
        data = json.loads(raw.strip())

        is_scam = data["risk_level"] in ["high", "critical"] or data["risk_score"] >= 60
        passed = (is_scam == case["expect_scam"])
        if not passed:
            all_passed = False

        print(f"Phrase: {case['phrase']}")
        print(f"  Risk Level: {data['risk_level']}, Score: {data['risk_score']}, Type: {data['scam_type']}")
        print(f"  Scam Detected: {is_scam} (Expected: {case['expect_scam']}) -> {'PASS' if passed else 'FAIL'}")
        print(f"  Evidence: {[e['title'] for e in data.get('evidence', [])]}")
        print(f"  Action: {data.get('recommended_action', '')}")
        print("-" * 50)

    print(f"SMOKE TEST RESULT: {'ALL PASSED' if all_passed else 'SOME FAILED'}")
    return all_passed

if __name__ == "__main__":
    run_smoke_test()
