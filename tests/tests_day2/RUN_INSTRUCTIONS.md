# Run Instructions for T5 QA Pipeline (Docker Compose)

This setup runs a 3-service pipeline:
1. **qa-api**: The FastAPI T5 service.
2. **redis**: Cache layer to store generated questions.
3. **redis-commander**: Web UI to view the cache.

## 1. Start the Pipeline
This will build the API image (including pre-downloading the T5 model) and start all services.

```bash
cd /home/harshil/Documents/vcc/vcc-project/V2AI-CloudNative/tests/tests_day2
docker-compose up --build -d
```

## 2. Verify Services are Running
```bash
docker-compose ps
```
- `qa-api`: http://localhost:8000
- `redis-commander`: http://localhost:8081

## 3. Test Full Pipeline (End-to-End)

### Step A: First Request (Cache MISS)
Run the test script. The first run will generate the question using the T5 model.
```bash
bash test_qa_endpoint.sh
```
Check the logs to see the "Cache MISS" and "Generation" logs:
```bash
docker logs qa-api
```

### Step B: Second Request (Cache HIT)
Run the test script again. It should be much faster as it pulls from Redis.
```bash
bash test_qa_endpoint.sh
```
Check the logs again to see the "Cache HIT".

### Step C: Visualize Cache
Open your browser and go to: **http://localhost:8081**
You will see the `redis` host. Expand it to see the cached context-question pairs.

## 4. Cleanup
```bash
docker-compose down
```
