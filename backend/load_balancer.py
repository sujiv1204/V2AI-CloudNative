import itertools
import httpx
import logging
from typing import List

logger = logging.getLogger(__name__)

class MLLoadBalancer:
    """Simple round-robin load balancer for ML pipeline instances"""

    def __init__(self, urls: List[str]):
        self.urls = urls
        self._cycle = itertools.cycle(urls)
        logger.info(f"Load balancer initialized with {len(urls)} ML instances: {urls}")

    def get_next_url(self) -> str:
        """Get next ML pipeline URL in round-robin fashion"""
        return next(self._cycle)

    async def call_ml_service(self, endpoint: str, **kwargs) -> dict:
        """Call ML service with automatic failover"""
        errors = []

        for _ in range(len(self.urls)):
            url = self.get_next_url()
            full_url = f"{url}{endpoint}"

            try:
                async with httpx.AsyncClient(timeout=300.0) as client:
                    if 'files' in kwargs:
                        response = await client.post(full_url, files=kwargs['files'])
                    elif 'json' in kwargs:
                        response = await client.post(full_url, json=kwargs['json'])
                    else:
                        response = await client.get(full_url)

                    response.raise_for_status()
                    logger.info(f"ML call successful: {url}")
                    return response.json()

            except Exception as e:
                errors.append(f"{url}: {str(e)}")
                logger.warning(f"ML call failed on {url}: {e}")
                continue

        # All instances failed
        raise Exception(f"All ML instances failed: {errors}")


# Global load balancer instance
_load_balancer = None

def get_load_balancer() -> MLLoadBalancer:
    """Get or create load balancer instance"""
    global _load_balancer
    if _load_balancer is None:
        import os
        urls_str = os.getenv("ML_PIPELINE_URLS", os.getenv("ML_PIPELINE_URL", "http://localhost:8001"))
        urls = [url.strip() for url in urls_str.split(",")]
        _load_balancer = MLLoadBalancer(urls)
    return _load_balancer
