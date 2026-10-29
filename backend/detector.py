"""
Core scam detection logic and fallback heuristics for DigiLens.
Standard library only, zero external dependencies required for standalone testing.
"""
import re
from urllib.parse import urlparse

def local_heuristic_fallback(transcript: str) -> dict:
    lower = transcript.lower()
    score = 0
    warnings = []
    scam_type = "unknown"

    if any(k in lower for k in ["digital arrest", "arrest warrant", "customs parcel", "cbi officer", "narcotics"]):
        score += 55
        scam_type = "digital_arrest"
        warnings.append({
            "title": "Digital Arrest / Law Enforcement Impersonation",
            "description": "Claims of digital arrest or customs parcel seizure by police/CBI.",
            "icon": "gavel"
        })

    if any(k in lower for k in ["anydesk", "teamviewer", "rustdesk", "screen share", "apk file"]):
        score += 45
        scam_type = "remote_access"
        warnings.append({
            "title": "Remote Screen Sharing Request",
            "description": "Requests to install remote-desktop applications for device control.",
            "icon": "screen_share"
        })

    if any(k in lower for k in ["otp", "cvv", "pin", "card number", "password"]):
        score += 40
        scam_type = "otp_theft"
        warnings.append({
            "title": "Credential & OTP Theft",
            "description": "Requests to disclose sensitive banking credentials over call.",
            "icon": "credit_card"
        })

    if any(k in lower for k in ["transfer money", "security deposit", "refundable amount", "1 lakh", "50,000"]):
        score += 45
        if scam_type == "unknown":
            scam_type = "money_demand"
        warnings.append({
            "title": "Suspicious Money Transfer Demand",
            "description": "Demands for immediate funds transfer or security deposits.",
            "icon": "payments"
        })

    if score >= 70:
        risk_level = "critical"
    elif score >= 45:
        risk_level = "high"
    elif score >= 25:
        risk_level = "medium"
    elif score >= 10:
        risk_level = "low"
    else:
        risk_level = "safe"

    action = "Disconnect call immediately. Dial National Cyber Helpline 1930." if score >= 45 else "Exercise caution. Verify via official helplines."

    return {
        "risk_level": risk_level,
        "risk_score": min(score, 100),
        "scam_type": scam_type,
        "evidence": warnings,
        "transcript_uncertain": len(transcript.split()) < 4,
        "recommended_action": action,
        "analysis_method": "local_fallback"
    }

def local_sms_heuristic_fallback(body: str, sender: str = "") -> dict:
    lower = body.lower()
    score = 0
    warnings = []
    scam_type = "unknown"

    # 1. Manufactured Urgency
    if any(k in lower for k in ["urgent", "immediately", "within 24 hours", "act now", "suspended tonight", "blocked today"]):
        score += 20
        warnings.append({
            "title": "Manufactured Urgency",
            "description": "Urgent deadlines designed to induce panic.",
            "icon": "schedule"
        })

    # 2. OTP / Credential Harvesting
    has_otp = any(k in lower for k in ["otp", "one time password", "verification code", "cvv", "pin", "card number"])
    if has_otp:
        score += 30
        scam_type = "otp_theft"
        warnings.append({
            "title": "OTP / Credential Request",
            "description": "Requests to disclose sensitive verification codes or card numbers.",
            "icon": "pin"
        })
        if any(k in lower for k in ["share this", "share your", "share otp", "tell otp", "send otp"]) and not any(k in lower for k in ["do not share", "don't share", "never share"]):
            score += 25

    # 3. Account Block / Fake KYC
    if any(k in lower for k in ["kyc", "pan", "aadhaar", "account blocked", "account suspended", "debit card blocked", "verify kyc"]):
        score += 30
        scam_type = "fake_kyc"
        warnings.append({
            "title": "Fake KYC / Account Suspension Threat",
            "description": "Claims that bank account or PAN/Aadhaar will be blocked.",
            "icon": "account_balance"
        })

    # 4. Utility Disconnection Extortion
    if any(k in lower for k in ["electricity", "power disconnected", "bill unpaid", "fastag", "gas connection", "bescom", "tata power", "adani power", "mseb"]):
        score += 25
        scam_type = "utility_threat"
        warnings.append({
            "title": "Utility Disconnection Threat",
            "description": "Fake power or utility disconnection notices.",
            "icon": "bolt"
        })

    # 5. Lottery / Advance-fee scam
    if any(k in lower for k in ["congratulations won", "lottery", "lucky draw", "prize", "crore", "kbc winner"]):
        score += 50
        scam_type = "lottery_scam"
        warnings.append({
            "title": "Advance-fee Prize Scam",
            "description": "Unsolicited claims of cash prizes or lottery winnings.",
            "icon": "card_giftcard"
        })

    # 6. Embedded URLs
    if "http://" in lower or "https://" in lower or ".xyz" in lower or ".top" in lower or ".click" in lower or "bit.ly" in lower:
        score += 25
        warnings.append({
            "title": "Embedded External Web Link",
            "description": "Message contains external link often pointing to phishing portals.",
            "icon": "link"
        })

    # 7. Law enforcement / Digital arrest
    if any(k in lower for k in ["digital arrest", "cbi", "police officer", "customs seizure", "narcotics"]):
        score += 60
        scam_type = "digital_arrest"
        warnings.append({
            "title": "Digital Arrest / Law Enforcement Extortion",
            "description": "Coercive claims of arrest warrants or police action.",
            "icon": "gavel"
        })

    if score >= 70:
        risk_level = "critical"
    elif score >= 45:
        risk_level = "high"
    elif score >= 25:
        risk_level = "medium"
    elif score >= 10:
        risk_level = "low"
    else:
        risk_level = "safe"

    action = "Do NOT click any link, call numbers, or share OTPs. Report to Chakshu (sancharsaathi.gov.in) or dial 1930." if score >= 45 else "Verify unexpected messages directly with official customer support."

    return {
        "risk_level": risk_level,
        "risk_score": min(score, 100),
        "scam_type": scam_type,
        "evidence": warnings,
        "transcript_uncertain": len(body.split()) < 3,
        "recommended_action": action,
        "analysis_method": "local_fallback"
    }

# ─── URL Heuristic Detector (Pure Python implementation matching DigiLens URL Analysis Service) ───

BRAND_SIGNATURES = {
    "sbi": ["sbi.co.in", "onlinesbi.sbi", "onlinesbi.com", "sbicap.com", "sbicard.com"],
    "hdfc": ["hdfcbank.com", "hdfcsec.com", "hdfcfund.com"],
    "icici": ["icicibank.com", "icicidirect.com", "icicibank.co.in"],
    "axis": ["axisbank.com", "axisdirect.in"],
    "paytm": ["paytm.com", "paytmbank.com"],
    "phonepe": ["phonepe.com"],
    "gpay": ["pay.google.com"],
    "paypal": ["paypal.com", "paypal.me"],
    "amazon": ["amazon.in", "amazon.com", "amazonpay.in"],
    "flipkart": ["flipkart.com"],
    "apple": ["apple.com", "icloud.com"],
    "google": ["google.com", "google.co.in", "googleapis.com"],
    "microsoft": ["microsoft.com", "live.com", "outlook.com", "office.com"],
    "facebook": ["facebook.com", "fb.com", "fb.me"],
    "instagram": ["instagram.com"],
    "whatsapp": ["whatsapp.com"],
    "incometax": ["incometax.gov.in", "incometaxindia.gov.in"],
    "aadhaar": ["uidai.gov.in"],
    "epfo": ["epfindia.gov.in"],
}

HIGH_RISK_TLDS = {
    ".xyz", ".top", ".click", ".work", ".download", ".stream", ".loan", ".men",
    ".win", ".zip", ".mov", ".tk", ".ml", ".ga", ".cf", ".gq", ".cc", ".buzz",
    ".icu", ".monster", ".surf", ".rest", ".fit"
}

MODERATE_RISK_TLDS = {
    ".info", ".biz", ".space", ".site", ".online", ".club", ".live", ".store",
    ".fun", ".host", ".website", ".pw"
}

SHORTENER_DOMAINS = {
    "bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd", "buff.ly",
    "rebrand.ly", "shorturl.at", "cutt.ly", "rb.gy", "surl.li", "tiny.cc",
    "v.gd", "qr.ae", "lnkd.in"
}

def analyze_url_heuristics(raw_url: str) -> dict:
    """
    Standard DigiLens URL heuristic analysis.
    Identical scoring and risk classification as DigiLens UrlAnalysisService in Flutter.
    """
    trimmed = raw_url.strip()
    lower = trimmed.lower()

    if lower.startswith("javascript:") or lower.startswith("data:"):
        return {
            "risk_level": "critical",
            "risk_score": 90,
            "title": "Dangerous Non-HTTP URI Scheme",
            "warnings": ["Executable non-HTTP scheme detected"]
        }

    # Prepend https if scheme is missing
    if not (lower.startswith("http://") or lower.startswith("https://")):
        trimmed = f"https://{trimmed}"

    parsed = urlparse(trimmed)
    host = (parsed.hostname or "").lower()
    path = (parsed.path or "").lower()
    full_url = trimmed.lower()

    if not host:
        return {
            "risk_level": "critical",
            "risk_score": 90,
            "title": "Invalid URL",
            "warnings": ["URL could not be parsed"]
        }

    score = 0
    warnings = []

    # 1. IP address URL
    if re.match(r"^(\d{1,3}\.){3}\d{1,3}$", host) or (":" in host and re.match(r"^[0-9a-f:]+$", host)):
        score += 35
        warnings.append("IP address instead of domain name")

    # 2. Suspicious TLD
    for tld in HIGH_RISK_TLDS:
        if host.endswith(tld):
            score += 25
            warnings.append(f"High-risk domain extension ({tld})")
            break
    else:
        for tld in MODERATE_RISK_TLDS:
            if host.endswith(tld):
                score += 12
                warnings.append(f"Uncommon domain extension ({tld})")
                break

    # 3. URL Shortener
    if host in SHORTENER_DOMAINS:
        score += 35
        warnings.append("URL shortener detected")

    # 4. Brand impersonation / typosquatting
    normalized_host = host.replace("0", "o").replace("1", "l").replace("rn", "m").replace("vv", "w").replace("cl", "d")
    for keyword, official_domains in BRAND_SIGNATURES.items():
        mentions_directly = keyword in host
        mentions_normalized = keyword in normalized_host

        if not mentions_directly and not mentions_normalized:
            continue

        if any(host == d or host.endswith(f".{d}") for d in official_domains):
            continue  # Legitimate official domain

        if not mentions_directly and mentions_normalized:
            score += 55
            warnings.append(f"Lookalike domain for {keyword}")
        else:
            is_gov = keyword in ["incometax", "aadhaar", "epfo"]
            score += 55 if is_gov else 35
            warnings.append(f"Possible brand impersonation ({keyword})")

    # 5. Sensitive action keywords in path
    sensitive_patterns = ["login", "signin", "sign-in", "verify", "secure", "account", "update", "confirm", "banking", "password", "credential", "authenticate", "wallet", "payment"]
    matches = [p for p in sensitive_patterns if p in path]
    if len(matches) >= 2:
        score += 15
        warnings.append(f"Sensitive action keywords in URL path: {', '.join(matches)}")

    # 6. HTTP scheme
    if parsed.scheme == "http":
        score += 10
        warnings.append("No HTTPS encryption")

    # 7. Punycode
    if "xn--" in host:
        score += 30
        warnings.append("Internationalized domain (punycode)")

    # 8. Excessive length
    if len(full_url) > 200:
        score += 10
        warnings.append("Unusually long URL")

    # 9. Credential prefix (@)
    if "@" in full_url and not full_url.startswith("mailto:"):
        score += 80
        warnings.append("Credential prefix in URL")

    # Risk level classification
    if score >= 80:
        risk_level = "critical"
    elif score >= 55:
        risk_level = "high"
    elif score >= 35:
        risk_level = "medium"
    elif score >= 15:
        risk_level = "low"
    else:
        risk_level = "safe"

    return {
        "risk_level": risk_level,
        "risk_score": min(score, 100),
        "warnings": warnings
    }
