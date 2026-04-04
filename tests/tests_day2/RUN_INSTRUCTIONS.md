# Run Instructions for T5 QA Service

Follow these steps to build, run, and verify the containerized T5 Question Generation service.

## 1. Build the Docker Image
This installs **CPU-only** PyTorch (via the PyTorch CPU wheel index), Python dependencies, and pre-downloads `t5-small` into the image cache. You need internet access during `docker build` for pip and Hugging Face.

```bash
cd /home/harshil/Documents/vcc/vcc-project/V2AI-CloudNative/tests/tests_day2
docker build -t qa-service .
```

## 2. Run the Container
Start the container in detached mode and map port 8000. The app is started with **uvicorn** (see `Dockerfile` `CMD`).

```bash
docker run -d -p 8000:8000 --name qa-test qa-service
```

View logs (model load can take a few seconds on first request):

```bash
docker logs -f qa-test
```

## 3. Verify Endpoints

### Using Bash (curl)
```bash
bash test_qa_endpoint.sh
```

### Using Python
```bash
python3 test_qa_api.py
```

## 4. Cleanup
Stop and remove the container when finished.

```bash
docker stop qa-test && docker rm qa-test
```
