from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from qg_logic import QuestionGenerator
import uvicorn
import logging
import time
import os
import redis

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("api.log"),
        logging.StreamHandler()
    ]
)

# Initialize Redis
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
try:
    cache = redis.Redis(host=REDIS_HOST, port=6379, decode_responses=True)
    logging.info(f"Connected to Redis at {REDIS_HOST}")
except Exception as e:
    logging.error(f"Failed to connect to Redis: {e}")
    cache = None

app = FastAPI(title="T5 Question Generation API")

# Initialize the generator globally
qg = QuestionGenerator()

class QARequest(BaseModel):
    context: str

class QAResponse(BaseModel):
    context: str
    question: str

@app.get("/")
async def root():
    return {"message": "T5 Question Generation API is running"}

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    logging.info(f"{request.method} {request.url.path} | Status: {response.status_code} | Duration: {duration:.2f}s")
    return response

@app.post("/qa", response_model=QAResponse)
async def generate_qa(request: QARequest):
    if not request.context.strip():
        raise HTTPException(status_code=400, detail="Context cannot be empty")
    
    # Check cache
    if cache:
        try:
            cached_q = cache.get(request.context)
            if cached_q:
                logging.info(f"Cache HIT for: {request.context[:30]}...")
                return QAResponse(context=request.context, question=cached_q)
        except Exception as e:
            logging.warning(f"Cache read error: {e}")

    try:
        logging.info(f"Cache MISS. Generating question for: {request.context[:30]}...")
        question = qg.generate(request.context)
        
        # Save to cache
        if cache:
            try:
                cache.set(request.context, question)
            except Exception as e:
                logging.warning(f"Cache write error: {e}")

        return QAResponse(
            context=request.context,
            question=question
        )
    except Exception as e:
        logging.error(f"Generation error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
