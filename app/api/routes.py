from fastapi import APIRouter, UploadFile, File
from fastapi.concurrency import run_in_threadpool
from app.schemas.request_response import TextRequest
from app.services.transcription import transcribe_audio
from app.services.summarization import summarize_text
from app.services.qa import generate_questions
import tempfile
import logging
import os

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------
# TRANSCRIPT
# ---------------------------
@router.post("/transcript")
async def transcript(file: UploadFile = File(...)):
    temp_path = None

    try:
        if not file.filename.lower().endswith((".wav", ".mp3", ".m4a")):
            return {"status": "error", "message": "Unsupported file format"}

        if file.content_type not in ["audio/wav", "audio/mpeg", "audio/mp4"]:
            return {"status": "error", "message": "Invalid content type"}

        content = await file.read()

        if not content:
            return {"status": "error", "message": "Empty file uploaded"}

        if len(content) > 20 * 1024 * 1024:
            return {"status": "error", "message": "File too large (max 20MB)"}

        ext = os.path.splitext(file.filename)[1]

        with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as temp:
            temp.write(content)
            temp_path = temp.name

        result = await run_in_threadpool(transcribe_audio, temp_path)

        if isinstance(result, dict) and result.get("status") == "error":
            return result

        return {
            "status": "success",
            "data": {
                "transcript": result
            }
        }

    except Exception as e:
        logger.error(f"Transcript failed: {str(e)}")
        return {"status": "error", "message": str(e)}

    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception as cleanup_error:
                logger.warning(f"Temp file cleanup failed: {cleanup_error}")


# ---------------------------
# SUMMARIZE
# ---------------------------
@router.post("/summarize")
async def summarize(req: TextRequest):
    result = await run_in_threadpool(summarize_text, req.text)

    if isinstance(result, dict) and result.get("status") == "error":
        return result

    return {
        "status": "success",
        "data": {
            "summary": result
        }
    }


# ---------------------------
# QA
# ---------------------------
@router.post("/qa")
async def qa(req: TextRequest):
    result = await run_in_threadpool(generate_questions, req.text)

    if isinstance(result, dict) and result.get("status") == "error":
        return result

    return {
        "status": "success",
        "data": {
            "questions": result
        }
    }


# ---------------------------
# PIPELINE (TRANSCRIPT → SUMMARY)
# ---------------------------
@router.post("/pipeline")
async def pipeline(file: UploadFile = File(...)):
    temp_path = None

    try:
        if not file.filename.lower().endswith((".wav", ".mp3", ".m4a")):
            return {"status": "error", "message": "Unsupported file format"}

        content = await file.read()

        if not content:
            return {"status": "error", "message": "Empty file uploaded"}

        ext = os.path.splitext(file.filename)[1]

        with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as temp:
            temp.write(content)
            temp_path = temp.name

        # STEP 1: TRANSCRIPTION
        transcript = await run_in_threadpool(transcribe_audio, temp_path)

        if isinstance(transcript, dict):
            return transcript

        # STEP 2: SUMMARIZATION
        summary = await run_in_threadpool(summarize_text, transcript)

        if isinstance(summary, dict):
            return summary

        return {
            "status": "success",
            "data": {
                "transcript": transcript,
                "summary": summary
            }
        }

    except Exception as e:
        logger.error(f"Pipeline failed: {str(e)}")
        return {"status": "error", "message": str(e)}

    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception as cleanup_error:
                logger.warning(f"Temp file cleanup failed: {cleanup_error}")