import os
import torch
import logging
import time
from transformers import pipeline, AutoTokenizer

# ---------------------------
# LOGGING CONFIG
# ---------------------------
logger = logging.getLogger(__name__)

# ---------------------------
# DEVICE CONFIG
# ---------------------------
DEVICE = 0 if torch.cuda.is_available() else -1

# ---------------------------
# ENV-BASED CONFIG
# ---------------------------
MODEL_NAME = os.getenv("MODEL_NAME", "sshleifer/distilbart-cnn-12-6")

if torch.cuda.is_available():
    MAX_INPUT_LENGTH = int(os.getenv("MAX_INPUT_LENGTH", 12000))
    MAX_TOKENS = int(os.getenv("MAX_TOKENS", 800))
else:
    MAX_INPUT_LENGTH = int(os.getenv("MAX_INPUT_LENGTH", 5000))
    MAX_TOKENS = int(os.getenv("MAX_TOKENS", 300))  # optimized

SUMMARY_MAX_LEN = int(os.getenv("SUMMARY_MAX_LEN", 80))
SUMMARY_MIN_LEN = int(os.getenv("SUMMARY_MIN_LEN", 20))

# ---------------------------
# GLOBAL LAZY LOADING
# ---------------------------
summarizer = None
tokenizer = None

def get_summarizer():
    global summarizer, tokenizer

    if summarizer is None or tokenizer is None:
        try:
            logger.info(f"Loading summarization model on device {DEVICE}")

            summarizer = pipeline(
                "summarization",
                model=MODEL_NAME,
                device=DEVICE
            )

            tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

            logger.info("Summarization model loaded successfully")

        except Exception as e:
            logger.error(f"Model loading failed: {str(e)}")
            raise e

    return summarizer, tokenizer


# ---------------------------
# TOKEN-BASED CHUNKING
# ---------------------------
def chunk_text_by_tokens(text, tokenizer):
    tokens = tokenizer.encode(text)

    chunks = []
    for i in range(0, len(tokens), MAX_TOKENS):
        chunk_tokens = tokens[i:i + MAX_TOKENS]
        chunk = tokenizer.decode(chunk_tokens, skip_special_tokens=True)
        chunks.append(chunk)

    return chunks


# ---------------------------
# MAIN FUNCTION
# ---------------------------
def summarize_text(text: str):
    start_time = time.time()   # ✅ START TIMER

    try:
        logger.info("Starting summarization")

        # LOAD MODEL (LAZY)
        summarizer, tokenizer = get_summarizer()

        # EMPTY CHECK
        if not text or len(text.strip()) == 0:
            logger.warning("Empty input received")
            return {
                "status": "error",
                "message": "Empty input text"
            }

        text = text.strip()

        # SAFETY LIMIT - truncate if too large
        if len(text) > MAX_INPUT_LENGTH:
            logger.warning(f"Input text too large ({len(text)} chars), truncating to {MAX_INPUT_LENGTH}")
            text = text[:MAX_INPUT_LENGTH]

        # SHORT TEXT
        if len(text.split()) <= 25:
            logger.info("Short text detected")
            return text

        # TOKEN CHUNKING
        chunks = chunk_text_by_tokens(text, tokenizer)

        # LIMIT CHUNKS (safety)
        if len(chunks) > 10:
            logger.warning("Too many chunks, truncating")
            chunks = chunks[:10]

        logger.info(f"Processing {len(chunks)} chunks")

        summaries = []
        for chunk in chunks:
            result = summarizer(
                chunk,
                max_length=SUMMARY_MAX_LEN,
                min_length=SUMMARY_MIN_LEN,
                do_sample=False
            )
            summaries.append(result[0]['summary_text'].strip())

        # MERGE
        final_summary = " ".join(summaries)

        # CLEAN
        final_summary = final_summary.replace(" .", ".")
        final_summary = final_summary.replace(" ,", ",")
        final_summary = " ".join(final_summary.split())

        logger.info("Summarization completed")

        return final_summary

    except Exception as e:
        logger.error(f"Summarization failed: {str(e)}")

        return {
            "status": "error",
            "message": f"Summarization failed: {str(e)}"
        }

    finally:
        end_time = time.time()   #  END TIMER
        logger.info(f"Summarization time: {end_time - start_time:.2f}s")