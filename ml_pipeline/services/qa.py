import os
import torch
import logging
import time
import threading
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

logger = logging.getLogger(__name__)

MAX_INPUT_LENGTH = int(os.getenv("QA_MAX_INPUT_LENGTH", 2000))
NUM_QUESTIONS = int(os.getenv("QA_NUM_QUESTIONS", 3))

qa_model = None
qa_tokenizer = None
_model_lock = threading.Lock()


def get_qa_model():
    global qa_model, qa_tokenizer

    if qa_model is None or qa_tokenizer is None:
        with _model_lock:
            if qa_model is None or qa_tokenizer is None:  # Double-check
                try:
                    model_name = "t5-small"
                    logger.info(f"Loading QA model: {model_name}")
                    qa_tokenizer = AutoTokenizer.from_pretrained(model_name)
                    qa_model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
                    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
                    qa_model.to(device)
                    logger.info(f"QA model loaded on {device}")
                except Exception as e:
                    logger.error(f"QA model loading failed: {str(e)}")
                    raise e

    return qa_model, qa_tokenizer


def generate_questions(text: str):
    start_time = time.time()

    try:
        logger.info("Starting question generation")

        model, tokenizer = get_qa_model()
        device = next(model.parameters()).device

        if not text or len(text.strip()) == 0:
            logger.warning("Empty input received")
            return {"status": "error", "message": "Empty input text"}

        text = text.strip()

        if len(text) > MAX_INPUT_LENGTH:
            logger.warning(f"Input too large ({len(text)} chars), truncating to {MAX_INPUT_LENGTH}")
            text = text[:MAX_INPUT_LENGTH]

        questions = []
        chunks = [text[i:i+500] for i in range(0, len(text), 500)][:NUM_QUESTIONS]

        for chunk in chunks:
            input_text = f"context: {chunk} question:"
            input_ids = tokenizer.encode(input_text, return_tensors="pt").to(device)

            outputs = model.generate(
                input_ids,
                max_length=64,
                num_beams=5,
                no_repeat_ngram_size=2,
                early_stopping=True
            )

            question = tokenizer.decode(outputs[0], skip_special_tokens=True)
            if question and question not in questions:
                questions.append(question)

        logger.info(f"Generated {len(questions)} questions")
        return questions

    except Exception as e:
        logger.error(f"QA generation failed: {str(e)}")
        return {"status": "error", "message": f"QA generation failed: {str(e)}"}

    finally:
        end_time = time.time()
        logger.info(f"QA time: {end_time - start_time:.2f}s")
