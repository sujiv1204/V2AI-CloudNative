from locust import HttpUser, task, between
import os

class MLPipelineUser(HttpUser):
    """Simulated user for Direct ML Pipeline testing"""

    wait_time = between(1, 2)

    def on_start(self):
        """Called when a user is spawned"""
        print(f"User spawned! Targeting host: {self.host}")

    @task(10)
    def ping_health(self):
        """Very frequent health check to verify connectivity"""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                print("Health check: SUCCESS")
                response.success()
            else:
                print(f"Health check: FAILED ({response.status_code})")
                response.failure(f"Status code: {response.status_code}")

    @task(2)
    def summarize(self):
        """Directly test the BART summarization model"""
        test_text = "AI is changing the world. " * 5
        self.client.post("/summarize", json={"text": test_text})

    @task(2)
    def generate_questions(self):
        """Directly test the T5 question generation model"""
        test_text = "The sky is blue. " * 5
        self.client.post("/qa", json={"text": test_text})
