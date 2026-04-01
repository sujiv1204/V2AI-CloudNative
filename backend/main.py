from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import os
from pathlib import Path

app = FastAPI(title="V2AI Backend")

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/upload")
async def upload_video(file: UploadFile = File(...)):
    """Upload video and orchestrate pipeline."""
    try:
        if not file.filename.endswith((".mp4", ".mov", ".avi")):
            return JSONResponse(
                status_code=400,
                content={"error": "Invalid file format. Use MP4, MOV, or AVI."}
            )

        file_path = UPLOAD_DIR / file.filename
        contents = await file.read()
        with open(file_path, "wb") as f:
            f.write(contents)

        return {
            "message": "File uploaded successfully",
            "filename": file.filename,
            "file_path": str(file_path)
        }

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": str(e)}
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
