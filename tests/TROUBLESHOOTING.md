# Troubleshooting Locust Activity (0 Requests)

If your Locust dashboard is showing **0 Requests** and no activity even after starting, follow these steps to identify the bottleneck.

## Check 1: Start Swarming
Ensure you have actually started the test:
1.  Enter the "Number of users" (e.g., `10`).
2.  Enter the "Spawn rate" (e.g., `1`).
3.  Click the **Start swarming** button.
4.  Check if the "Status" in the top-right corner says **"Running"**.

## Check 2: Terminal Output
Check the terminal where you ran the `locust` command. I have added diagnostic print statements to `tests/ml_locustfile.py`:
- You should see `User spawned! Targeting host: ...`
- You should see `Health check: SUCCESS` or `Health check: FAILED`
- If you see **NOTHING** in the terminal, Locust is not executing any tasks.

## Check 3: Host Header/URL
Ensure the host field in the Locust UI has the full protocol:
- **Correct**: `http://34.131.164.21:8001`
- **Incorrect**: `34.131.164.21:8001` (missing `http://`)

## Check 4: Python Environment
If Locust starts but shows an error immediately in the terminal:
- Ensure you are using the correct virtual environment:
  ```bash
  source ./venv/bin/activate
  ```
- Re-run the command:
  ```bash
  locust -f tests/ml_locustfile.py --host=http://<ML_IP>:8001
  ```

## Check 5: Firewall / Port 8001
If the terminal shows `Connection refused` or `Timeout`, the port 8001 might be closed:
- Verify accessibility with `curl`:
  ```bash
  curl http://<ML_IP>:8001/health
  ```
- If `curl` hangs, the issue is infrastructure/firewall, not Locust.

## Check 6: Class Filtering
If you have multiple files or classes, Locust might be confused. Use the explicit class name if needed:
```bash
locust -f tests/ml_locustfile.py MLPipelineUser --host=http://<ML_IP>:8001
```
