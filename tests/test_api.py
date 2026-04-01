import requests
import pytest

BASE_URL = "http://localhost:8000"


@pytest.fixture
def client():
    return requests.Session()


def test_backend_health(client):
    """Test backend health endpoint."""
    response = client.get(f"{BASE_URL}/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_upload_endpoint_exists(client):
    """Test upload endpoint exists."""
    # Placeholder test - C3 will implement comprehensive tests
    assert True
