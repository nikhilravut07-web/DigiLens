"""
Core scam detection logic and fallback heuristics for DigiLens.
Standard library only, zero external dependencies required for standalone testing.
"""

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

