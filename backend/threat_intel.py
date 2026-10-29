import os
import httpx
import logging
from typing import Optional, Dict, Any

logger = logging.getLogger("digilens-threat-intel")

class ThreatIntelligenceService:
    def __init__(self):
        self.phishtank_api_key = os.getenv("PHISHTANK_API_KEY")
        self.urlhaus_api_key = os.getenv("URLHAUS_API_KEY") # Optional or bearer

    async def query_phishtank(self, url: str) -> Dict[Any, Any]:
        """
        Queries PhishTank API for phishing verification.
        Note: PhishTank official API endpoint for check is POST /api/v2/ or JSON/XML submission.
        Official doc: https://phishtank.org/api_info.php / developer_info.php
        Typically takes format: url=<url>&format=json[&app_key=<key>]
        """
        endpoint = "https://checkurl.phishtank.com/checkurl/"
        data = {
            "url": url,
            "format": "json"
        }
        if self.phishtank_api_key:
            data["app_key"] = self.phishtank_api_key

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.post(endpoint, data=data, headers={"User-Agent": "DigiLens-Security-App/1.0"})
                if response.status_code == 200:
                    try:
                        json_resp = response.json()
                        results = json_resp.get("results", {})
                        in_database = results.get("in_database", False)
                        verified = results.get("valid", False)
                        return {
                            "source": "PhishTank",
                            "queried": True,
                            "match_found": in_database and verified,
                            "is_phishing": verified,
                            "details": results,
                            "error": None
                        }
                    except Exception as e:
                        return {"source": "PhishTank", "queried": True, "match_found": False, "is_phishing": False, "error": f"Malformed JSON: {str(e)}"}
                elif response.status_code == 429:
                    return {"source": "PhishTank", "queried": False, "match_found": False, "is_phishing": False, "error": "Rate limit exceeded (HTTP 429)"}
                else:
                    return {"source": "PhishTank", "queried": False, "match_found": False, "is_phishing": False, "error": f"HTTP status {response.status_code}"}
        except httpx.TimeoutException:
            return {"source": "PhishTank", "queried": False, "match_found": False, "is_phishing": False, "error": "Lookup timed out"}
        except Exception as e:
            return {"source": "PhishTank", "queried": False, "match_found": False, "is_phishing": False, "error": str(e)}

    async def query_urlhaus(self, url: str) -> Dict[Any, Any]:
        """
        Queries URLhaus API (abuse.ch) for malware distribution URLs.
        Official API doc: https://urlhaus.abuse.ch/api/
        Endpoint: POST https://urlhaus-api.abuse.ch/v1/url/
        Data: url=<url>
        """
        endpoint = "https://urlhaus-api.abuse.ch/v1/url/"
        data = {
            "url": url
        }
        headers = {}
        if self.urlhaus_api_key:
            headers["API-KEY"] = self.urlhaus_api_key

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.post(endpoint, data=data, headers=headers)
                if response.status_code == 200:
                    try:
                        json_resp = response.json()
                        status = json_resp.get("query_status")
                        if status == "ok":
                            return {
                                "source": "URLhaus",
                                "queried": True,
                                "match_found": True,
                                "is_malware": True,
                                "threat": json_resp.get("threat"),
                                "payloads": json_resp.get("payloads", []),
                                "details": json_resp,
                                "error": None
                            }
                        else:
                            return {
                                "source": "URLhaus",
                                "queried": True,
                                "match_found": False,
                                "is_malware": False,
                                "details": json_resp,
                                "error": None
                            }
                    except Exception as e:
                        return {"source": "URLhaus", "queried": True, "match_found": False, "is_malware": False, "error": f"Malformed JSON: {str(e)}"}
                elif response.status_code == 429:
                    return {"source": "URLhaus", "queried": False, "match_found": False, "is_malware": False, "error": "Rate limit exceeded (HTTP 429)"}
                else:
                    return {"source": "URLhaus", "queried": False, "match_found": False, "is_malware": False, "error": f"HTTP status {response.status_code}"}
        except httpx.TimeoutException:
            return {"source": "URLhaus", "queried": False, "match_found": False, "is_malware": False, "error": "Lookup timed out"}
        except Exception as e:
            return {"source": "URLhaus", "queried": False, "match_found": False, "is_malware": False, "error": str(e)}

    async def check_url(self, url: str) -> Dict[str, Any]:
        phishtank_res = await self.query_phishtank(url)
        urlhaus_res = await self.query_urlhaus(url)

        is_threat = phishtank_res.get("is_phishing", False) or urlhaus_res.get("is_malware", False)

        return {
            "url": url,
            "confirmed_threat": is_threat,
            "phishtank": phishtank_res,
            "urlhaus": urlhaus_res
        }
