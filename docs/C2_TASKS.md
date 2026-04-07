# C2 (Sagnik) Tasks: Firestore Storage & Basic UI

## Overview

Your tasks for Day 5-8:

1. **Store ML results in Firestore** (transcript, summary, questions)
2. **Build a basic web UI** for uploading videos and viewing results

**Important:** Follow these instructions EXACTLY. Do not deviate or add extra complexity.

---

## Prerequisites

Before starting, make sure you have:

1. ✅ Git installed
2. ✅ Docker and Docker Compose installed
3. ✅ Python 3.10+ installed
4. ✅ Received `gcp-key.json` and `.env` from C1 (sujiv)
5. ✅ GCP IAM access granted by C1

### Verify GCP Access

```bash
# Install gcloud CLI if not installed
# https://cloud.google.com/sdk/docs/install

# Login to GCP
gcloud auth login

# Set project
gcloud config set project v2aicloud

# Verify access
gcloud firestore databases list
```

Expected output:

```
NAME: v2aidb
LOCATION: ...
```

---

## Part 1: Setup Your Development Environment

### Step 1.1: Clone and Setup

```bash
# Clone the repository
git clone <repo-url>
cd V2AI-CloudNative

# Switch to main and pull latest
git checkout main
git pull origin main

# Create your feature branch
git checkout -b feature/c2-firestore-ui

# Copy secret files (received from C1)
cp ~/Downloads/gcp-key.json .
cp ~/Downloads/.env .

# Verify files exist
ls -la gcp-key.json .env
```

### Step 1.2: Verify Local Setup Works

```bash
# Build and start containers
docker-compose up -d --build

# Wait 30 seconds for containers to start
sleep 30

# Check containers are running
docker-compose ps

# Test health endpoints
curl http://localhost:8000/health
curl http://localhost:8001/health
```

Expected output:

```json
{"status":"ok"}
{"status":"ok"}
```

### Step 1.3: Test Current Pipeline

```bash
# Upload a test video (use a small file first)
curl -X POST -F "file=@lecture.mp4" http://localhost:8000/upload
```

Note the `file_id` from the response. Then check status:

```bash
# Replace FILE_ID with actual ID
curl http://localhost:8000/status/FILE_ID
```

---

## Part 2: Firestore Storage (ALREADY DONE - VERIFY ONLY)

**Good news:** The current code ALREADY stores ML results in Firestore!

Look at `backend/main.py` line ~85-100 in the `process_ml_pipeline()` function:

```python
# Update Firestore with results
gcp_service.store_metadata(file_id, {
    "status": "processed",
    "processing_completed_at": datetime.now().isoformat(),
    "ml_results": {
        "transcript": transcript_result,
        "summary": summary_result,
        "questions": qa_result,
        ...
    }
})
```

### Step 2.1: Verify Firestore Storage

After uploading a video and waiting for processing:

```bash
# Check Firestore in GCP Console
# Go to: https://console.cloud.google.com/firestore/databases/v2aidb/data/videos

# Or use gcloud
gcloud firestore documents list \
  --database=v2aidb \
  --collection=videos \
  --project=v2aicloud
```

You should see documents with:

- `file_id`
- `status`: "processed"
- `ml_results.transcript.text`: Full transcript
- `ml_results.summary.text`: Summary
- `ml_results.questions.questions`: Array of questions

### Step 2.2: If Results Are Missing (Fix)

If results are not being stored, check the backend logs:

```bash
docker-compose logs backend | grep -i "firestore\|error"
```

Common issues:

1. `gcp-key.json` missing → Copy from C1
2. Wrong project ID → Check `.env` file
3. Permission denied → Ask C1 to grant IAM roles

---

## Part 3: Build Basic UI

Create a simple web interface served from the backend.

### Step 3.1: Create UI Directory Structure

```bash
mkdir -p backend/static
mkdir -p backend/templates
```

### Step 3.2: Create the HTML File

Create `backend/templates/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>V2AI - Lecture Video Understanding</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }

            body {
                font-family:
                    -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
                    Oxygen, Ubuntu, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                padding: 20px;
            }

            .container {
                max-width: 900px;
                margin: 0 auto;
            }

            h1 {
                color: white;
                text-align: center;
                margin-bottom: 30px;
                font-size: 2.5rem;
            }

            .card {
                background: white;
                border-radius: 16px;
                padding: 30px;
                margin-bottom: 20px;
                box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
            }

            .card h2 {
                color: #333;
                margin-bottom: 20px;
                font-size: 1.5rem;
            }

            .upload-area {
                border: 3px dashed #667eea;
                border-radius: 12px;
                padding: 40px;
                text-align: center;
                cursor: pointer;
                transition: all 0.3s ease;
            }

            .upload-area:hover {
                background: #f0f4ff;
                border-color: #764ba2;
            }

            .upload-area.dragover {
                background: #e8edff;
                border-color: #764ba2;
            }

            #fileInput {
                display: none;
            }

            .upload-icon {
                font-size: 48px;
                margin-bottom: 10px;
            }

            .btn {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                border: none;
                padding: 15px 40px;
                border-radius: 8px;
                font-size: 16px;
                cursor: pointer;
                margin-top: 20px;
                transition: transform 0.2s ease;
            }

            .btn:hover {
                transform: scale(1.05);
            }

            .btn:disabled {
                opacity: 0.5;
                cursor: not-allowed;
                transform: none;
            }

            .status {
                padding: 20px;
                border-radius: 8px;
                margin-top: 20px;
            }

            .status.processing {
                background: #fff3cd;
                border: 1px solid #ffc107;
            }

            .status.success {
                background: #d4edda;
                border: 1px solid #28a745;
            }

            .status.error {
                background: #f8d7da;
                border: 1px solid #dc3545;
            }

            .results-section {
                margin-top: 20px;
            }

            .results-section h3 {
                color: #333;
                margin-bottom: 10px;
                padding-bottom: 10px;
                border-bottom: 2px solid #667eea;
            }

            .transcript-box,
            .summary-box {
                background: #f8f9fa;
                padding: 20px;
                border-radius: 8px;
                margin-bottom: 20px;
                max-height: 300px;
                overflow-y: auto;
                white-space: pre-wrap;
                line-height: 1.6;
            }

            .questions-list {
                list-style: none;
            }

            .questions-list li {
                background: #f0f4ff;
                padding: 15px 20px;
                margin-bottom: 10px;
                border-radius: 8px;
                border-left: 4px solid #667eea;
            }

            .spinner {
                display: inline-block;
                width: 20px;
                height: 20px;
                border: 3px solid #f3f3f3;
                border-top: 3px solid #667eea;
                border-radius: 50%;
                animation: spin 1s linear infinite;
                margin-right: 10px;
            }

            @keyframes spin {
                0% {
                    transform: rotate(0deg);
                }
                100% {
                    transform: rotate(360deg);
                }
            }

            .hidden {
                display: none;
            }

            .file-info {
                margin-top: 15px;
                padding: 10px;
                background: #e8edff;
                border-radius: 8px;
            }

            .progress-bar {
                height: 8px;
                background: #e0e0e0;
                border-radius: 4px;
                margin-top: 15px;
                overflow: hidden;
            }

            .progress-bar-fill {
                height: 100%;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                transition: width 0.5s ease;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🎓 V2AI - Lecture Video Understanding</h1>

            <!-- Upload Card -->
            <div class="card">
                <h2>📤 Upload Video</h2>
                <div class="upload-area" id="uploadArea">
                    <div class="upload-icon">🎬</div>
                    <p>Drag & drop your lecture video here</p>
                    <p style="color: #666; margin-top: 10px;">
                        or click to browse
                    </p>
                    <p style="color: #999; margin-top: 10px; font-size: 14px;">
                        Supported: MP4, AVI, MOV (max 100MB)
                    </p>
                </div>
                <input type="file" id="fileInput" accept="video/*" />
                <div id="fileInfo" class="file-info hidden">
                    <strong>Selected:</strong>
                    <span id="fileName"></span> (<span id="fileSize"></span>)
                </div>
                <button class="btn" id="uploadBtn" disabled>
                    Upload & Process
                </button>
            </div>

            <!-- Status Card -->
            <div class="card hidden" id="statusCard">
                <h2>⏳ Processing Status</h2>
                <div class="status processing" id="statusBox">
                    <span class="spinner"></span>
                    <span id="statusText">Uploading video...</span>
                </div>
                <div class="progress-bar">
                    <div
                        class="progress-bar-fill"
                        id="progressBar"
                        style="width: 0%"
                    ></div>
                </div>
            </div>

            <!-- Results Card -->
            <div class="card hidden" id="resultsCard">
                <h2>📊 Results</h2>

                <div class="results-section">
                    <h3>📝 Transcript</h3>
                    <div class="transcript-box" id="transcriptText"></div>
                </div>

                <div class="results-section">
                    <h3>📋 Summary</h3>
                    <div class="summary-box" id="summaryText"></div>
                </div>

                <div class="results-section">
                    <h3>❓ Generated Questions</h3>
                    <ul class="questions-list" id="questionsList"></ul>
                </div>
            </div>
        </div>

        <script>
            const uploadArea = document.getElementById("uploadArea");
            const fileInput = document.getElementById("fileInput");
            const uploadBtn = document.getElementById("uploadBtn");
            const fileInfo = document.getElementById("fileInfo");
            const fileName = document.getElementById("fileName");
            const fileSize = document.getElementById("fileSize");
            const statusCard = document.getElementById("statusCard");
            const statusBox = document.getElementById("statusBox");
            const statusText = document.getElementById("statusText");
            const progressBar = document.getElementById("progressBar");
            const resultsCard = document.getElementById("resultsCard");
            const transcriptText = document.getElementById("transcriptText");
            const summaryText = document.getElementById("summaryText");
            const questionsList = document.getElementById("questionsList");

            let selectedFile = null;

            // Drag and drop handlers
            uploadArea.addEventListener("click", () => fileInput.click());

            uploadArea.addEventListener("dragover", (e) => {
                e.preventDefault();
                uploadArea.classList.add("dragover");
            });

            uploadArea.addEventListener("dragleave", () => {
                uploadArea.classList.remove("dragover");
            });

            uploadArea.addEventListener("drop", (e) => {
                e.preventDefault();
                uploadArea.classList.remove("dragover");
                if (e.dataTransfer.files.length) {
                    handleFile(e.dataTransfer.files[0]);
                }
            });

            fileInput.addEventListener("change", () => {
                if (fileInput.files.length) {
                    handleFile(fileInput.files[0]);
                }
            });

            function handleFile(file) {
                if (!file.type.startsWith("video/")) {
                    alert("Please select a video file");
                    return;
                }
                selectedFile = file;
                fileName.textContent = file.name;
                fileSize.textContent = formatFileSize(file.size);
                fileInfo.classList.remove("hidden");
                uploadBtn.disabled = false;
            }

            function formatFileSize(bytes) {
                if (bytes < 1024) return bytes + " B";
                if (bytes < 1024 * 1024)
                    return (bytes / 1024).toFixed(1) + " KB";
                return (bytes / (1024 * 1024)).toFixed(1) + " MB";
            }

            uploadBtn.addEventListener("click", async () => {
                if (!selectedFile) return;

                uploadBtn.disabled = true;
                statusCard.classList.remove("hidden");
                resultsCard.classList.add("hidden");

                try {
                    // Upload file
                    updateStatus("Uploading video...", 10);
                    const formData = new FormData();
                    formData.append("file", selectedFile);

                    const uploadResponse = await fetch("/upload", {
                        method: "POST",
                        body: formData,
                    });

                    const uploadData = await uploadResponse.json();

                    if (uploadData.error) {
                        throw new Error(uploadData.error);
                    }

                    const fileId = uploadData.file_id;
                    updateStatus("Processing video...", 30);

                    // Poll for status
                    await pollStatus(fileId);
                } catch (error) {
                    showError(error.message);
                }
            });

            async function pollStatus(fileId) {
                const maxAttempts = 60; // 5 minutes max
                let attempts = 0;

                while (attempts < maxAttempts) {
                    try {
                        const response = await fetch(`/status/${fileId}`);
                        const data = await response.json();

                        if (data.status === "processed") {
                            updateStatus("Processing complete!", 100);
                            showResults(data);
                            return;
                        } else if (data.status === "processing_failed") {
                            throw new Error(
                                "Processing failed: " +
                                    (data.error || "Unknown error"),
                            );
                        } else {
                            // Still processing
                            const progress = Math.min(30 + attempts * 2, 90);
                            updateStatus(
                                "Processing... (this may take 1-3 minutes)",
                                progress,
                            );
                        }
                    } catch (error) {
                        if (error.message.includes("Processing failed")) {
                            throw error;
                        }
                        // Network error, continue polling
                    }

                    attempts++;
                    await sleep(5000); // Poll every 5 seconds
                }

                throw new Error("Processing timeout - please try again");
            }

            function sleep(ms) {
                return new Promise((resolve) => setTimeout(resolve, ms));
            }

            function updateStatus(message, progress) {
                statusText.textContent = message;
                progressBar.style.width = progress + "%";
                statusBox.className = "status processing";
            }

            function showError(message) {
                statusBox.className = "status error";
                statusText.textContent = "❌ Error: " + message;
                uploadBtn.disabled = false;
            }

            function showResults(data) {
                statusBox.className = "status success";
                statusText.textContent = "✅ Processing complete!";

                resultsCard.classList.remove("hidden");

                // Display transcript
                const transcript =
                    data.ml_results?.transcript?.text ||
                    "No transcript available";
                transcriptText.textContent = transcript;

                // Display summary
                const summary =
                    data.ml_results?.summary?.text || "No summary available";
                summaryText.textContent = summary;

                // Display questions
                const questions = data.ml_results?.questions?.questions || [];
                questionsList.innerHTML = "";
                questions.forEach((q, i) => {
                    const li = document.createElement("li");
                    li.textContent = `${i + 1}. ${q}`;
                    questionsList.appendChild(li);
                });

                if (questions.length === 0) {
                    questionsList.innerHTML = "<li>No questions generated</li>";
                }

                uploadBtn.disabled = false;
            }
        </script>
    </body>
</html>
```

### Step 3.3: Update Backend to Serve UI

Edit `backend/main.py` to add static file serving and templates.

Add these imports at the top:

```python
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from starlette.requests import Request
```

Add these lines after `app = FastAPI()`:

```python
# Serve static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Templates
templates = Jinja2Templates(directory="templates")
```

Add this endpoint after the health endpoint:

```python
@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Serve the main UI page"""
    return templates.TemplateResponse("index.html", {"request": request})
```

### Step 3.4: Update Backend Dockerfile

Edit `backend/Dockerfile` to copy templates:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install ffmpeg
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create directories
RUN mkdir -p uploads templates static

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Step 3.5: Update Backend requirements.txt

Add Jinja2 to `backend/requirements.txt`:

```
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-multipart==0.0.6
ffmpeg-python==0.2.0
google-cloud-storage==2.10.0
google-cloud-firestore==2.13.0
pydantic-settings==2.1.0
python-dotenv==1.0.0
httpx==0.25.2
uuid6==2024.1.12
jinja2==3.1.2
aiofiles==23.2.1
```

### Step 3.6: Test the UI

```bash
# Rebuild and restart
docker-compose down
docker-compose up -d --build

# Wait for containers
sleep 30

# Open browser
echo "Open http://localhost:8000 in your browser"
```

You should see the V2AI upload interface. Test by:

1. Drag and drop a video file
2. Click "Upload & Process"
3. Wait for processing (1-3 minutes)
4. View transcript, summary, and questions

---

## Part 4: Commit Your Changes

### Step 4.1: Check What Changed

```bash
git status
```

### Step 4.2: Add and Commit

```bash
# Add specific files (NOT gcp-key.json or .env!)
git add backend/templates/index.html
git add backend/main.py
git add backend/Dockerfile
git add backend/requirements.txt

# Commit
git commit -m "Add web UI for video upload and results display"
```

### Step 4.3: Push to Your Branch

```bash
git push origin feature/c2-firestore-ui
```

### Step 4.4: Create Pull Request

Go to GitHub and create a PR from `feature/c2-firestore-ui` to `main`.

---

## Verification Checklist

Before marking your task complete, verify:

- [ ] Local docker-compose runs without errors
- [ ] `curl http://localhost:8000/health` returns `{"status":"ok"}`
- [ ] Opening `http://localhost:8000` shows the UI
- [ ] Can upload a video through the UI
- [ ] Status updates while processing
- [ ] Results (transcript, summary, questions) display after processing
- [ ] Firestore contains the document with all results
- [ ] All changes committed and pushed
- [ ] PR created

---

## Common Issues & Solutions

### Issue: "Template not found"

**Solution:**

```bash
# Make sure templates directory exists in container
docker-compose exec backend ls -la templates/
# Should show index.html
```

If missing, rebuild:

```bash
docker-compose down
docker-compose up -d --build
```

### Issue: "Jinja2 import error"

**Solution:** Make sure `jinja2` is in requirements.txt and rebuild.

### Issue: "CORS error in browser"

**Solution:** Add CORS middleware to backend/main.py:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Issue: "Upload timeout"

**Solution:** The video might be too large. Try with a smaller file first (<50MB).

### Issue: "Processing stuck"

**Solution:** Check ML pipeline logs:

```bash
docker-compose logs ml_pipeline
```

---

## Files You Should Have Modified

```
backend/
├── main.py              # Added UI route and template serving
├── requirements.txt     # Added jinja2, aiofiles
├── Dockerfile           # Added template directory creation
└── templates/
    └── index.html       # NEW - The UI page
```

---

## Timeline

| Day   | Task                          | Hours |
| ----- | ----------------------------- | ----- |
| Day 5 | Setup + Verify Firestore      | 2-3   |
| Day 5 | Create UI HTML                | 3-4   |
| Day 6 | Integrate UI with backend     | 2-3   |
| Day 6 | Test end-to-end               | 2-3   |
| Day 7 | Polish UI + Fix bugs          | 3-4   |
| Day 8 | Final testing + Documentation | 2-3   |

---

## Need Help?

1. Check the logs: `docker-compose logs -f`
2. Ask in team chat with specific error message
3. Include output of `docker-compose ps` and error logs

**DO NOT** make changes to files outside of `backend/` directory unless absolutely necessary and discussed with team.
