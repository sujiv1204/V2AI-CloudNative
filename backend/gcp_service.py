import os
from google.cloud import storage, firestore
from config import settings
import logging

logger = logging.getLogger(__name__)


def init_gcp_clients():
    """Initialize GCP clients (GCS and Firestore)."""
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = settings.gcs_key_path

    storage_client = storage.Client(project=settings.gcp_project_id)
    firestore_client = firestore.Client(
        project=settings.gcp_project_id, database=settings.firestore_db_name)

    return storage_client, firestore_client


def upload_to_gcs(file_path: str, destination_blob_name: str) -> str:
    """Upload file to GCS and return public URL."""
    try:
        storage_client, _ = init_gcp_clients()
        bucket = storage_client.bucket(settings.gcs_bucket_name)
        blob = bucket.blob(destination_blob_name)
        blob.upload_from_filename(file_path)
        logger.info(
            f"Uploaded {file_path} to gs://{settings.gcs_bucket_name}/{destination_blob_name}")
        return f"gs://{settings.gcs_bucket_name}/{destination_blob_name}"
    except Exception as e:
        logger.error(f"GCS upload failed: {str(e)}")
        raise


def store_metadata(file_id: str, metadata: dict, merge: bool = True) -> bool:
    """Store video metadata in Firestore. Uses merge by default to avoid overwriting."""
    try:
        _, firestore_client = init_gcp_clients()
        firestore_client.collection(settings.firestore_collection).document(
            file_id).set(metadata, merge=merge)
        logger.info(
            f"Stored metadata for {file_id} in Firestore (merge={merge})")
        return True
    except Exception as e:
        logger.error(f"Firestore storage failed: {str(e)}")
        raise


def get_metadata(file_id: str) -> dict:
    """Retrieve video metadata from Firestore."""
    try:
        _, firestore_client = init_gcp_clients()
        doc = firestore_client.collection(
            settings.firestore_collection).document(file_id).get()
        if doc.exists:
            return doc.to_dict()
        return None
    except Exception as e:
        logger.error(f"Firestore retrieval failed: {str(e)}")
        raise
