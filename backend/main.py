from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import logging
from pathlib import Path
from datetime import datetime
import uuid6

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


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/upload")
async def upload_video(file: UploadFile = File(...)):
    """Upload video, extract audio, upload to GCS, and store metadata."""
    file_id = str(uuid6.uuid6())

    try:
        # 1. Validate file format
        if not file.filename.endswith((".mp4", ".mov", ".avi")):
            return JSONResponse(
                status_code=400,
                content={"error": "Invalid file format. Use MP4, MOV, or AVI."}
            )

        # 2. Save video locally
        video_path = UPLOAD_DIR / f"{file_id}_{file.filename}"
        contents = await file.read()
        with open(video_path, "wb") as f:
            f.write(contents)
        logger.info(f"Video saved: {video_path}")

        # 3. Extract audio
        audio_path = AUDIO_DIR / f"{file_id}.wav"
        extract_audio(str(video_path), str(audio_path))

        # 4. Upload audio to GCS
        audio_gcs_path = upload_to_gcs(str(audio_path), f"audio/{file_id}.wav")

        # 5. Upload video to GCS
        video_gcs_path = upload_to_gcs(str(video_path), f"videos/{file_id}_{file.filename}")

        # 6. Store metadata in Firestore
        metadata = {
            "file_id": file_id,
            "original_filename": file.filename,
            "video_path": video_gcs_path,
            "audio_path": audio_gcs_path,
            "local_video_path": str(video_path),
            "local_audio_path": str(audio_path),
            "upload_timestamp": datetime.utcnow().isoformat(),
            "status": "uploaded"
        }
        store_metadata(file_id, metadata)

        return {
            "file_id": file_id,
            "message": "Video uploaded and processed",
            "filename": file.filename,
            "video_path": video_gcs_path,
            "audio_path": audio_gcs_path,
            "status": "uploaded"
        }

    except Exception as e:
        logger.error(f"Upload failed for {file_id}: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"error": str(e)}
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
