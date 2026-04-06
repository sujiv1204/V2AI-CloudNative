import tempfile
import logging
import os
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

from services.transcription import transcribe_audio
from services.summarization import summarize_text
from services.qa import generate_questions

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

app = FastAPI(title="V2AI ML Pipeline")


class TextRequest(BaseModel):
    text: str


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/ready")
async def ready():
    return {"status": "ready"}


@app.post("/transcript")
async def transcribe(file: UploadFile = File(...)):
    """Transcribe audio to text using Whisper."""
    temp_path = None

    try:
        if not file.filename.lower().endswith((".wav", ".mp3", ".m4a", ".ogg", ".mp4")):
            return JSONResponse(
                status_code=400,
                content={"status": "error", "message": "Unsupported format"}
            )

        content = await file.read()
        if not content:
            return JSONResponse(
                status_code=400,
                content={"status": "error", "message": "Empty file"}
            )

        if len(content) > 50 * 1024 * 1024:
            return JSONResponse(
                status_code=400,
                content={"status": "error", "message": "File too large (max 50MB)"}
            )

        ext = os.path.splitext(file.filename)[1]
        with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as temp:
            temp.write(content)
            temp_path = temp.name

        result = await run_in_threadpool(transcribe_audio, temp_path)

        if isinstance(result, dict) and result.get("status") == "error":
            return JSONResponse(status_code=500, content=result)

        return {
            "status": "success",
            "text": result,
            "filename": file.filename
        }

    except Exception as e:
        logger.error(f"Transcript error: {e}")
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)}
        )

    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception as e:
                logger.warning(f"Cleanup error: {e}")


@app.post("/summarize")
async def summarize(req: TextRequest):
    """Summarize text using BART."""
    try:
        if not req.text or len(req.text.strip()) == 0:
            return JSONResponse(
                status_code=400,
                content={"status": "error", "message": "Empty text"}
            )

        result = await run_in_threadpool(summarize_text, req.text)

        if isinstance(result, dict) and result.get("status") == "error":
            return JSONResponse(status_code=500, content=result)

        return {
            "status": "success",
            "text": result,
            "input_length": len(req.text),
            "output_length": len(result) if isinstance(result, str) else 0
        }

    except Exception as e:
        logger.error(f"Summarize error: {e}")
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)}
        )


@app.post("/qa")
async def generate_qa(req: TextRequest):
    """Generate questions from text using T5."""
    try:
        if not req.text or len(req.text.strip()) == 0:
            return JSONResponse(
                status_code=400,
                content={"status": "error", "message": "Empty text"}
            )

        result = await run_in_threadpool(generate_questions, req.text)

        if isinstance(result, dict) and result.get("status") == "error":
            return JSONResponse(status_code=500, content=result)

        return {
            "status": "success",
            "questions": result,
            "count": len(result) if isinstance(result, list) else 0,
            "input_length": len(req.text)
        }

    except Exception as e:
        logger.error(f"QA error: {e}")
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)}
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
