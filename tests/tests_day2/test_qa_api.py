import json
import sys

import requests

def test_qa_endpoint():
    url = "http://localhost:8000/qa"
    payload = {
        "context": "Artificial intelligence is the intelligence of machines or software, as opposed to the intelligence of humans or animals."
    }
    headers = {
        "Content-Type": "application/json"
    }

    print(f"Sending POST request to {url}...")
    try:
        response = requests.post(url, data=json.dumps(payload), headers=headers)
        response.raise_for_status()
        
        result = response.json()
        print("\nSuccess!")
        print(f"Context: {result['context']}")
        print(f"Generated Question: {result['question']}")
        
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)

if __name__ == "__main__":
    test_qa_endpoint()
