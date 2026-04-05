import torch
import logging
import time
from faster_whisper import WhisperModel

# ---------------------------
# LOGGING CONFIG
# ---------------------------
logger = logging.getLogger(__name__)

# ---------------------------
# DEVICE CONFIG
# ---------------------------
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
COMPUTE_TYPE = "float16" if DEVICE == "cuda" else "int8"

# ---------------------------
# MODEL CONFIG
# ---------------------------
WHISPER_MODEL_SIZE = "base"

# ---------------------------
# GLOBAL LAZY LOADING
# ---------------------------
model = None

def get_whisper_model():
    global model

    if model is None:
        try:
            logger.info(f"Loading Whisper model: {WHISPER_MODEL_SIZE} on {DEVICE}")

            model = WhisperModel(
                WHISPER_MODEL_SIZE,
                device=DEVICE,
                compute_type=COMPUTE_TYPE
            )

            logger.info("Whisper model loaded successfully")

        except Exception as e:
            logger.error(f"GPU load failed, falling back to CPU: {str(e)}")

            model = WhisperModel(
                WHISPER_MODEL_SIZE,
                device="cpu",
                compute_type="int8"
            )

    return model


# ---------------------------
# TRANSCRIPTION FUNCTION
# ---------------------------
def transcribe_audio(audio_path: str):
    start_time = time.time()   # ✅ START TIMER

    try:
        logger.info(f"Starting transcription for: {audio_path}")

        # LOAD MODEL (LAZY)
        model = get_whisper_model()

        # SAFETY CHECK
        if not audio_path:
            raise ValueError("Invalid audio path")

        # TRANSCRIBE
        segments, _ = model.transcribe(
            audio_path,
            beam_size=5,
            vad_filter=True
        )

        # COMBINE TEXT
        text = " ".join([segment.text for segment in segments])

        # CLEAN OUTPUT
        text = text.replace("\n", " ").strip()
        text = " ".join(text.split())

        logger.info("Transcription completed successfully")

        return text

    except Exception as e:
        logger.error(f"Transcription failed: {str(e)}")

        return {
            "status": "error",
            "message": f"Transcription failed: {str(e)}"
        }

    finally:
        end_time = time.time()   #  END TIMER
        logger.info(f"Transcription time: {end_time - start_time:.2f}s")