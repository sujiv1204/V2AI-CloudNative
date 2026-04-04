from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from qg_logic import QuestionGenerator
import uvicorn

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

@app.post("/qa", response_model=QAResponse)
async def generate_qa(request: QARequest):
    if not request.context.strip():
        raise HTTPException(status_code=400, detail="Context cannot be empty")
    
    try:
        question = qg.generate(request.context)
        return QAResponse(
            context=request.context,
            question=question
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
