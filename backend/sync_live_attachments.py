import base64
import json
import urllib.request
from pathlib import Path

BASE_URL = "https://janmitra-backend-twij.onrender.com/api/v1"

ITEMS = [
    {
        "dept": "PWD (Karukachal Road)",
        "grievance_id": "eab550d2-2e04-4b37-ad69-1dfa8db32a62",
        "attachment_id": "a118dcc1-c503-486c-89b1-0e72e2fb80e5",
        "image_path": r"C:\Users\Asus\.gemini\antigravity\brain\653d86d4-78a3-4866-a752-37eb551f4660\.user_uploaded\media_1791104652426.jpg",
    },
    {
        "dept": "KWA (Manarcad Pipe Leak)",
        "grievance_id": "443e40f0-9f9f-446f-abc5-95f6b4681957",
        "attachment_id": "035991b7-9fad-421f-b0f3-e0218ecd4148",
        "image_path": r"C:\Users\Asus\.gemini\antigravity\brain\653d86d4-78a3-4866-a752-37eb551f4660\.user_uploaded\media_1791104662691.jpg",
    },
    {
        "dept": "KSEB (Pampady 11KV Post)",
        "grievance_id": "b21d93bd-2387-419e-b228-2f7265adb80e",
        "attachment_id": "74eb8f09-7b71-4956-894b-edf718f4efab",
        "image_path": r"C:\Users\Asus\.gemini\antigravity\brain\653d86d4-78a3-4866-a752-37eb551f4660\.user_uploaded\media_1791104671957.jpg",
    },
]

def sync():
    for item in ITEMS:
        g_id = item["grievance_id"]
        a_id = item["attachment_id"]
        fpath = Path(item["image_path"])
        file_bytes = fpath.read_bytes()
        b64_str = base64.b64encode(file_bytes).decode("ascii")
        print(f"\n--- Syncing {item['dept']} ---")
        print(f"File size: {len(file_bytes)} bytes, Base64 chars: {len(b64_str)}")
        url = f"{BASE_URL}/grievances/{g_id}/attachments/{a_id}/content"
        payload = json.dumps({"file_content_base64": b64_str}).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=payload,
            headers={"Content-Type": "application/json", "User-Agent": "JanMitraSync/1.0"},
            method="PUT"
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as res:
                response_data = json.loads(res.read().decode("utf-8"))
                print(f"SUCCESS ({res.status}): {response_data}")
        except Exception as e:
            print(f"FAILED: {e}")

if __name__ == "__main__":
    sync()
