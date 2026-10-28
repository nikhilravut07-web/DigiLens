# DigiLens AI Backend (FastAPI + Google Gemini)

This backend mediates AI-powered voice scam analysis for DigiLens using Google Gemini (`gemini-2.5-flash` with fallback to `gemini-1.5-flash`).

## Features
- **Zero Secrets in Mobile Client**: Flutter communicates with this endpoint; the Gemini API key stays on the server.
- **Strict Input Validation**: Request payloads are validated via Pydantic with limits on input size.
- **Graceful Local Heuristics Fallback**: If the Gemini API key is missing, network is down, or quotas are exhausted (HTTP 429), the backend automatically falls back to deterministic local heuristic rules.
- **Standardized Schema**: Always returns validated JSON matching the DigiLens detection schema:
  - `risk_level`: safe, low, medium, high, critical
  - `risk_score`: 0-100
  - `scam_type`: digital_arrest, bank_impersonation, otp_theft, remote_access, money_demand, unknown
  - `evidence`: list of warning indicators
  - `transcript_uncertain`: boolean
  - `recommended_action`: guidance for the user

## Setup and Run

1. **Install Dependencies**:
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

2. **Configure Gemini API Key**:
   Create a `.env` file in `backend/` (or copy from `.env.example`):
   ```bash
   cp .env.example .env
   ```
   Add your Gemini API key from [Google AI Studio](https://aistudio.google.com/):
   ```env
   GEMINI_API_KEY=your_actual_gemini_api_key
   PORT=8000
   ```

3. **Start the Server**:
   ```bash
   python main.py
   ```
   Or via uvicorn directly:
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

4. **Run Unit Tests**:
   ```bash
   python test_suite.py
   ```
