from locust import HttpUser, task, between


class V2AIUser(HttpUser):
    wait_time = between(1, 3)

    @task
    def health_check(self):
        """Check backend health."""
        self.client.get("/health")

    @task(2)
    def upload_video(self):
        """Simulate video upload."""
        # C3 will implement with actual files
        pass
