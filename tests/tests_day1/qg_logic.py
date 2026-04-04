from transformers import T5ForConditionalGeneration, T5Tokenizer
import torch

class QuestionGenerator:
    def __init__(self, model_name="t5-small"):
        print(f"Loading model {model_name}...")
        self.tokenizer = T5Tokenizer.from_pretrained(model_name)
        self.model = T5ForConditionalGeneration.from_pretrained(model_name)
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model.to(self.device)
        print(f"Model loaded on {self.device}")

    def generate(self, context, max_length=64):
        # Refining the prompt for better quality
        # T5-small often responds better to specific patterns like "context: ... question:"
        input_text = f"context: {context}  question:"
        
        input_ids = self.tokenizer.encode(input_text, return_tensors="pt").to(self.device)
        
        # Using top-p sampling for more natural questions
        outputs = self.model.generate(
            input_ids, 
            max_length=max_length, 
            num_beams=5,
            no_repeat_ngram_size=2,
            early_stopping=True
        )
        
        question = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
        return question

if __name__ == "__main__":
    qg = QuestionGenerator()
    sample_text = "The T5 model was proposed in the paper 'Exploring the Limits of Transfer Learning with a Unified Text-to-Text Transformer'."
    print(f"\nContext: {sample_text}")
    print(f"Generated Question: {qg.generate(sample_text)}?")
    
    sample_text_2 = "Artificial intelligence is the intelligence of machines or software, as opposed to the intelligence of humans or animals."
    print(f"\nContext: {sample_text_2}")
    print(f"Generated Question: {qg.generate(sample_text_2)}?")
