FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Hugging Face cache inside the image (pre-download + runtime)
ENV HF_HOME=/app/.cache/huggingface

# CPU-only PyTorch — default `pip install torch` pulls CUDA wheels and bloats the image
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY api_service.py qg_logic.py ./

# Warm cache so the container starts without downloading the model
RUN python3 -c "\
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer; \
name='t5-small'; \
AutoTokenizer.from_pretrained(name); \
AutoModelForSeq2SeqLM.from_pretrained(name); \
print('T5 pre-download OK')"

EXPOSE 8000

CMD ["uvicorn", "api_service:app", "--host", "0.0.0.0", "--port", "8000"]
