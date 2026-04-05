from fastapi import FastAPI, File, UploadFile, BackgroundTasks
from fastapi.responses import JSONResponse
import logging
from pathlib import Path
from datetime import datetime
import uuid6
import httpx

from config import settings
from audio_service import extract_audio
from gcp_service import upload_to_gcs, store_metadata

logging.basicConfig(level=settings.log_level)
logger = logging.getLogger(__name__)

app = FastAPI(title="V2AI Backend")

UPLOAD_DIR = Path(settings.upload_dir)
UPLOAD_DIR.mkdir(exist_ok=True)
AUDIO_DIR = UPLOAD_DIR / "audio"
AUDIO_DIR.mkdir(exist_ok=True)

ML_PIPELINE_URL = "http://ml_pipeline:8001"
TIMEOUT = 300.0


@app.get("/health")
async def health():
    return {"status": "ok"}


async def call_ml_endpoint(endpoint: str, method: str = "POST", **kwargs):
    """Call ML Pipeline endpoint with error handling."""
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            url = f"{ML_PIPELINE_URL}{endpoint}"
            if method == "POST":
                response = await client.post(url, **kwargs)
            else:
                response = await client.get(url, **kwargs)
            response.raise_for_status()
            return response.json()
    except httpx.TimeoutException:
        logger.error(f"Timeout calling {endpoint}")
        return {"status": "error", "message": f"Timeout calling {endpoint}"}
    except httpx.HTTPError as e:
        logger.error(f"HTTP error calling {endpoint}: {str(e)}")
        return {"status": "error", "message": str(e)}
    except Exception as e:
        logger.error(f"Error calling {endpoint}: {str(e)}")
        return {"status": "error", "message": str(e)}


async def process_ml_pipeline(file_id: str, audio_path: str):
    """Background task: Process audio through ML Pipeline."""
    try:
        logger.info(f"Starting background ML pipeline processing for file_id: {file_id}")

        transcript_result = None
        summary_result = None
        qa_result = None

        with open(audio_path, "rb") as audio_file:
            files = {"file": (f"{file_id}.wav", audio_file, "audio/wav")}
            logger.info("Calling /transcript endpoint...")
            transcript_result = await call_ml_endpoint("/transcript", method="POST", files=files)
            logger.info(f"Transcript response: {transcript_result}")

        if transcript_result and "status" not in transcript_result.get("status", ""):
            transcript_text = transcript_result.get("text", "")

            if transcript_text:
                logger.info("Calling /summarize endpoint...")
                summary_result = await call_ml_endpoint(
                    "/summarize",
                    method="POST",
                    params={"text": transcript_text}
                )
                logger.info(f"Summary response: {summary_result}")

                logger.info("Calling /qa endpoint...")
                qa_result = await call_ml_endpoint(
                    "/qa",
                    method="POST",
                    params={"text": transcript_text}
                )
                logger.info(f"QA response: {qa_result}")

        result = {
            "file_id": file_id,
            "transcript": transcript_result,
            "summary": summary_result,
            "questions": qa_result,
            "processing_completed_at": datetime.utcnow().isoformat()
        }

        metadata = {
            "ml_results": result,
            "status": "processed"
        }
        store_metadata(file_id, metadata)
        logger.info(f"Background processing completed for file_id: {file_id}")

    except Exception as e:
        logger.error(f"Background processing failed for {file_id}: {str(e)}")
        metadata = {
            "ml_results": {"status": "error", "message": str(e)},
            "status": "processing_failed"
        }
        store_metadata(file_id, metadata)


@app.post("/upload")
async def upload_video(file: UploadFile = File(...), background_tasks: BackgroundTasks = None):
    """Upload video and start background ML pipeline processing."""
    file_id = str(uuid6.uuid6())

    try:
        if not file.filename.endswith((".mp4", ".mov", ".avi")):
            return JSONResponse(
                status_code=400,
                content={"error": "Invalid file format. Use MP4, MOV, or AVI."}
            )

        video_path = UPLOAD_DIR / f"{file_id}_{file.filename}"
        contents = await file.read()
        with open(video_path, "wb") as f:
            f.write(contents)
        logger.info(f"Video saved: {video_path}")

        audio_path = AUDIO_DIR / f"{file_id}.wav"
        extract_audio(str(video_path), str(audio_path))
        logger.info(f"Audio extracted: {audio_path}")

        audio_gcs_path = upload_to_gcs(str(audio_path), f"audio/{file_id}.wav")
        video_gcs_path = upload_to_gcs(str(video_path), f"videos/{file_id}_{file.filename}")
        logger.info(f"Uploaded to GCS - Video: {video_gcs_path}, Audio: {audio_gcs_path}")

        metadata = {
            "file_id": file_id,
            "original_filename": file.filename,
            "video_path": video_gcs_path,
            "audio_path": audio_gcs_path,
            "local_video_path": str(video_path),
            "local_audio_path": str(audio_path),
            "upload_timestamp": datetime.utcnow().isoformat(),
            "status": "processing"
        }
        store_metadata(file_id, metadata)
        logger.info(f"Metadata stored in Firestore for file_id: {file_id}")

        if background_tasks:
            background_tasks.add_task(process_ml_pipeline, file_id, str(audio_path))
            logger.info(f"Background ML pipeline task queued for file_id: {file_id}")

        response_data = {
            "file_id": file_id,
            "filename": file.filename,
            "message": "Video uploaded. ML pipeline processing started in background.",
            "status": "queued",
            "video_path": video_gcs_path,
            "audio_path": audio_gcs_path,
            "note": "Check Firestore or use the status endpoint to monitor progress"
        }

        return response_data

    except Exception as e:
        logger.error(f"Upload failed for {file_id}: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"error": str(e), "file_id": file_id}
        )


@app.get("/status/{file_id}")
async def get_processing_status(file_id: str):
    """Get processing status and results for a file_id."""
    try:
        from gcp_service import get_metadata
        metadata = get_metadata(file_id)

        if not metadata:
            return JSONResponse(
                status_code=404,
                content={"error": "File not found", "file_id": file_id}
            )

        return {
            "file_id": file_id,
            "status": metadata.get("status", "unknown"),
            "original_filename": metadata.get("original_filename"),
            "upload_timestamp": metadata.get("upload_timestamp"),
            "ml_results": metadata.get("ml_results"),
            "processing_completed_at": metadata.get("ml_results", {}).get("processing_completed_at")
        }

    except Exception as e:
        logger.error(f"Error fetching status for {file_id}: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"error": str(e), "file_id": file_id}
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
