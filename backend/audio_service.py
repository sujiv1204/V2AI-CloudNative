import ffmpeg
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


def extract_audio(video_path: str, output_audio_path: str) -> str:
    """Extract audio from video file to WAV format."""
    try:
        video_path = Path(video_path)
        output_audio_path = Path(output_audio_path)

        output_audio_path.parent.mkdir(parents=True, exist_ok=True)

        ffmpeg.input(str(video_path)).audio.output(str(output_audio_path), acodec="pcm_s16le", ar=16000).run(
            capture_stdout=True, capture_stderr=True, quiet=True
        )

        logger.info(f"Audio extracted: {video_path} -> {output_audio_path}")
        return str(output_audio_path)
    except Exception as e:
        logger.error(f"Audio extraction failed: {str(e)}")
        raise
