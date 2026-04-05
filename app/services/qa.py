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
# ENV CONFIG (OPTIMIZED)
# ---------------------------
MODEL_NAME = os.getenv("QA_MODEL", "valhalla/t5-base-qg-hl")

MAX_INPUT_LENGTH = int(os.getenv("QA_MAX_INPUT_LENGTH", 2000))
MAX_TOKENS = int(os.getenv("QA_MAX_TOKENS", 300))   # 🔥 reduced

MAX_ATTEMPTS = int(os.getenv("QA_MAX_ATTEMPTS", 5)) # 🔥 reduced
NUM_QUESTIONS = int(os.getenv("QA_NUM_QUESTIONS", 2)) # 🔥 reduced

TEMPERATURE = float(os.getenv("QA_TEMPERATURE", 0.9))
TOP_K = int(os.getenv("QA_TOP_K", 50))
MAX_LEN = int(os.getenv("QA_MAX_LEN", 60))  # 🔥 reduced

# ---------------------------
# GLOBAL LAZY LOADING
# ---------------------------
qa_pipeline = None
tokenizer = None

def get_qa_model():
    global qa_pipeline, tokenizer

    if qa_pipeline is None or tokenizer is None:
        try:
            logger.info(f"Loading QA model on device {DEVICE}")

            qa_pipeline = pipeline(
                "text2text-generation",
                model=MODEL_NAME,
                device=DEVICE
            )

            tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

            logger.info("QA model loaded successfully")

        except Exception as e:
            logger.error(f"QA model loading failed: {str(e)}")
            raise e

    return qa_pipeline, tokenizer


# ---------------------------
# CLEAN FUNCTION
# ---------------------------
def clean_questions(questions):
    cleaned = []

    for q in questions:
        q = q.strip()
        q = q.replace(".?", "?").replace("..", ".")

        if not q.endswith("?"):
            continue

        if not q.lower().startswith(("what", "how", "why", "where", "which", "when")):
            continue

        q = q[0].upper() + q[1:]
        cleaned.append(q)

    return list(set(cleaned))


# ---------------------------
# TOKEN TRUNCATION
# ---------------------------
def truncate_text(text, tokenizer):
    inputs = tokenizer(
        text,
        max_length=MAX_TOKENS,
        truncation=True,
        return_tensors="pt"
    )

    return tokenizer.decode(inputs["input_ids"][0], skip_special_tokens=True)


# ---------------------------
# MAIN FUNCTION
# ---------------------------
def generate_questions(text: str):
    start_time = time.time()   # ✅ START TIMER

    try:
        logger.info("Starting question generation")

        # LOAD MODEL (LAZY)
        qa_pipeline, tokenizer = get_qa_model()

        # EMPTY CHECK
        if not text or len(text.strip()) == 0:
            logger.warning("Empty input received")
            return {
                "status": "error",
                "message": "Empty input text"
            }

        text = text.strip()

        # LENGTH CHECK
        if len(text) > MAX_INPUT_LENGTH:
            logger.warning("Input too large")
            return {
                "status": "error",
                "message": "Input text too large"
            }

        # TOKEN SAFE INPUT
        text = truncate_text(text, tokenizer)

        questions = set()
        attempts = 0

        while len(questions) < NUM_QUESTIONS * 2 and attempts < MAX_ATTEMPTS:
            result = qa_pipeline(
                f"generate question: {text}",
                max_length=MAX_LEN,
                do_sample=True,
                temperature=TEMPERATURE,
                top_k=TOP_K
            )

            q = result[0]['generated_text'].strip()
            questions.add(q)

            attempts += 1

        final_questions = clean_questions(list(questions))

        logger.info(f"Generated {len(final_questions)} questions")

        return final_questions[:NUM_QUESTIONS]

    except Exception as e:
        logger.error(f"QA generation failed: {str(e)}")

        return {
            "status": "error",
            "message": f"QA generation failed: {str(e)}"
        }

    finally:
        end_time = time.time()   #  END TIMER
        logger.info(f"QA time: {end_time - start_time:.2f}s")