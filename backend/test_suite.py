import unittest
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from detector import local_heuristic_fallback

class TestScamDetection(unittest.TestCase):
    def test_digital_arrest_detection(self):
        transcript = "This is CBI officer. You are under digital arrest. Transfer money immediately."
        res = local_heuristic_fallback(transcript)
        self.assertIn(res["risk_level"], ["high", "critical"])
        self.assertEqual(res["scam_type"], "digital_arrest")
        self.assertTrue(len(res["evidence"]) >= 1)

    def test_otp_theft_detection(self):
        transcript = "Please share your 6-digit OTP and CVV to verify your bank account."
        res = local_heuristic_fallback(transcript)
        self.assertIn(res["risk_level"], ["medium", "high", "critical"])
        self.assertEqual(res["scam_type"], "otp_theft")

    def test_remote_access_detection(self):
        transcript = "Install AnyDesk app from play store and give me code."
        res = local_heuristic_fallback(transcript)
        self.assertIn(res["risk_level"], ["medium", "high", "critical"])
        self.assertEqual(res["scam_type"], "remote_access")

    def test_benign_conversation(self):
        transcript = "Hi Mom, I am reaching home at 7 PM for dinner."
        res = local_heuristic_fallback(transcript)
        self.assertEqual(res["risk_level"], "safe")
        self.assertEqual(res["scam_type"], "unknown")
        self.assertEqual(len(res["evidence"]), 0)

    def test_uncertain_short_transcript(self):
        transcript = "Hello"
        res = local_heuristic_fallback(transcript)
        self.assertTrue(res["transcript_uncertain"])

if __name__ == "__main__":
    unittest.main()
