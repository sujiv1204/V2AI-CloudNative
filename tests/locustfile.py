from locust import HttpUser, task, between
import os
import random
from collections import deque

# Shared queue for file IDs to simulate real-world polling of recently uploaded files
uploaded_file_ids = deque(maxlen=100)

class V2AIUser(HttpUser):
    """Simulated user for V2AI API"""

    wait_time = between(1, 3)

    @task(10)
    def health_check(self):
        """Standard health check"""
        self.client.get("/health")

    @task(5)
    def check_status(self):
        """Poll status of a recently uploaded file"""
        if not uploaded_file_ids:
            # Fallback to a known ID or skip
            return
            
        file_id = random.choice(list(uploaded_file_ids))
        self.client.get(f"/status/{file_id}", name="/status/[file_id]")

    @task(2)
    def upload_video(self):
        """Upload a video file"""
        # Search for test video in multiple locations
        possible_paths = [
            "tests/test_video.mp4",
            "test_video.mp4",
            "lecture.mp4",
            "../lecture.mp4"
        ]
        
        test_video_path = None
        for p in possible_paths:
            if os.path.exists(p):
                test_video_path = p
                break

        if not test_video_path:
            # No video found, skipping task
            return

        with open(test_video_path, "rb") as f:
            files = {"file": ("test.mp4", f, "video/mp4")}
            with self.client.post("/upload", files=files, catch_response=True) as response:
                if response.status_code == 200:
                    try:
                        data = response.json()
                        file_id = data.get("file_id")
                        if file_id:
                            uploaded_file_ids.append(file_id)
                    except Exception:
                        pass
                    response.success()
                else:
                    response.failure(f"Upload failed ({response.status_code}): {response.text}")

    # @task(1)
    # def summarize_test(self):
    #     """Test summarization endpoint (proxied through backend)"""
    #     test_text = "Machine learning is the study of computer algorithms that improve automatically through experience. " * 20
    #     self.client.post("/summarize", json={"text": test_text})

    # @task(1)
    # def qa_test(self):
    #     """Test QA endpoint (proxied through backend)"""
    #     test_text = "The quick brown fox jumps over the lazy dog. Artificial intelligence is evolving rapidly. " * 15
    #     self.client.post("/qa", json={"text": test_text})
