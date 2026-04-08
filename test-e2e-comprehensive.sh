#!/bin/bash

################################################################################
# V2AI End-to-End Comprehensive Testing Script
# This script performs full integration testing of the V2AI system
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKEND_URL="http://localhost:8000"
ML_PIPELINE_URL="http://localhost:8001"
HEALTH_CHECK_RETRIES=30
HEALTH_CHECK_DELAY=2
TEST_VIDEO_PATH="test_video.mp4"
MAX_PROCESS_TIME=600  # 10 minutes max for processing

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"
}

################################################################################
# Pre-flight Checks
################################################################################

check_docker() {
    log_section "STEP 1: Checking Docker Installation"

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    log_success "Docker is installed"

    if ! docker ps &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    log_success "Docker daemon is running"
}

check_test_video() {
    log_section "STEP 2: Checking Test Video"

    if [ ! -f "$TEST_VIDEO_PATH" ]; then
        log_warning "Test video not found. Creating a minimal test video (5 seconds)..."

        # Create a minimal test video using ffmpeg
        if command -v ffmpeg &> /dev/null; then
            if [ ! -d "test_data" ]; then
                mkdir -p test_data
            fi

            # Create minimal video with silent audio
            ffmpeg -f lavfi -i color=c=blue:s=640x480:d=5 \
                    -f lavfi -i anullsrc=r=44100:cl=mono:d=5 \
                    -pix_fmt yuv420p -c:a aac "test_data/test_video.mp4" -y 2>/dev/null

            TEST_VIDEO_PATH="test_data/test_video.mp4"
            log_success "Test video created at $TEST_VIDEO_PATH"
        else
            log_error "FFmpeg not found. Cannot create test video. Please provide test_video.mp4"
            exit 1
        fi
    fi
    log_success "Test video found: $TEST_VIDEO_PATH"
}

################################################################################
# Service Health Checks
################################################################################

wait_for_service() {
    local url=$1
    local service_name=$2
    local retries=$HEALTH_CHECK_RETRIES

    log_info "Waiting for $service_name to be ready..."

    while [ $retries -gt 0 ]; do
        if curl -s "$url/health" > /dev/null 2>&1; then
            log_success "$service_name is ready"
            return 0
        fi

        retries=$((retries - 1))
        if [ $retries -gt 0 ]; then
            echo -n "."
            sleep $HEALTH_CHECK_DELAY
        fi
    done

    log_error "$service_name failed to start"
    return 1
}

check_services_health() {
    log_section "STEP 3: Checking Services Health"

    if ! docker compose ps | grep -q "Up"; then
        log_error "Docker services are not running. Starting docker compose..."
        docker compose up -d --build
    fi

    log_info "Checking Backend Service..."
    if wait_for_service "$BACKEND_URL" "Backend"; then
        log_success "Backend is running on port 8000"
    else
        log_error "Backend service is not responding"
        docker compose logs backend | tail -50
        exit 1
    fi

    log_info "Checking ML Pipeline Service..."
    if wait_for_service "$ML_PIPELINE_URL" "ML Pipeline"; then
        log_success "ML Pipeline is running on port 8001"
    else
        log_error "ML Pipeline service is not responding"
        docker compose logs ml_pipeline | tail -50
        exit 1
    fi
}

################################################################################
# API Endpoint Tests
################################################################################

test_health_endpoints() {
    log_section "STEP 4: Testing Health Endpoints"

    log_info "Testing Backend /health..."
    response=$(curl -s "$BACKEND_URL/health")
    if echo "$response" | grep -q '"status":"ok"'; then
        log_success "Backend /health: OK"
    else
        log_error "Backend /health failed: $response"
        return 1
    fi

    log_info "Testing ML Pipeline /health..."
    response=$(curl -s "$ML_PIPELINE_URL/health")
    if echo "$response" | grep -q '"status":"ok"'; then
        log_success "ML Pipeline /health: OK"
    else
        log_error "ML Pipeline /health failed: $response"
        return 1
    fi
}

test_ui_serving() {
    log_section "STEP 5: Testing UI Serving"

    log_info "Testing GET /"
    response=$(curl -s "$BACKEND_URL/")
    if echo "$response" | grep -q "V2AI"; then
        log_success "UI is being served correctly"
    else
        log_error "UI is NOT being served correctly"
        log_error "Response: ${response:0:200}"
        return 1
    fi
}

################################################################################
# Upload and Processing Tests
################################################################################

test_video_upload() {
    log_section "STEP 6: Testing Video Upload"

    log_info "Uploading test video: $TEST_VIDEO_PATH"

    response=$(curl -s -X POST -F "file=@$TEST_VIDEO_PATH" \
               -H "Content-Type: multipart/form-data" \
               "$BACKEND_URL/upload")

    log_info "Upload Response: $response"

    # Extract file_id from response
    FILE_ID=$(echo "$response" | grep -o '"file_id":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$FILE_ID" ]; then
        log_error "Failed to extract file_id from response"
        return 1
    fi

    if echo "$response" | grep -q "error"; then
        log_error "Upload failed: $response"
        return 1
    fi

    log_success "Video uploaded successfully"
    log_success "File ID: $FILE_ID"

    echo "$FILE_ID"
}

test_processing_status() {
    local file_id=$1
    local max_attempts=$((MAX_PROCESS_TIME / 5))
    local attempt=0

    log_section "STEP 7: Monitoring Processing Status"

    log_info "Polling status (max $MAX_PROCESS_TIME seconds)..."

    while [ $attempt -lt $max_attempts ]; do
        response=$(curl -s "$BACKEND_URL/status/$file_id")

        status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

        case "$status" in
            "uploaded")
                log_info "Status: Uploaded (waiting for processing...)"
                ;;
            "processing")
                log_info "Status: Processing... Attempt $((attempt + 1))/$max_attempts"
                ;;
            "processed")
                log_success "Status: Processing Complete!"
                echo "$response"
                return 0
                ;;
            "processing_failed")
                error=$(echo "$response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
                log_error "Processing failed: $error"
                return 1
                ;;
            *)
                log_warning "Unknown status: $status"
                ;;
        esac

        attempt=$((attempt + 1))
        if [ $attempt -lt $max_attempts ]; then
            sleep 5
        fi
    done

    log_error "Processing timeout after $MAX_PROCESS_TIME seconds"
    return 1
}

################################################################################
# Results Validation
################################################################################

validate_results() {
    local response=$1

    log_section "STEP 8: Validating Processing Results"

    # Check for transcript
    if echo "$response" | grep -q '"transcript"'; then
        log_success "✓ Transcript found in results"
    else
        log_error "✗ Transcript NOT found in results"
        return 1
    fi

    # Check for summary
    if echo "$response" | grep -q '"summary"'; then
        log_success "✓ Summary found in results"
    else
        log_error "✗ Summary NOT found in results"
        return 1
    fi

    # Check for questions
    if echo "$response" | grep -q '"questions"'; then
        log_success "✓ Questions found in results"
    else
        log_error "✗ Questions NOT found in results"
        return 1
    fi

    # Check for ml_results
    if echo "$response" | grep -q '"ml_results"'; then
        log_success "✓ ML results found in response"
    else
        log_error "✗ ML results NOT found in response"
        return 1
    fi
}

################################################################################
# C2 Task Verification
################################################################################

verify_c2_tasks() {
    log_section "STEP 9: Verifying C2 Task Completion"

    # Task 1: Firestore Storage
    log_info "Task 1: Verify Firestore Storage"
    if [ -f "backend/main.py" ]; then
        if grep -q "store_metadata" backend/main.py; then
            log_success "✓ Firestore integration found in backend"
        else
            log_error "✗ Firestore integration NOT found in backend"
            return 1
        fi
    fi

    # Task 2: UI Templates
    log_info "Task 2: Verify Web UI"
    if [ -f "backend/templates/index.html" ]; then
        log_success "✓ UI template file exists"
        if grep -q "V2AI" backend/templates/index.html; then
            log_success "✓ UI template has V2AI branding"
        fi
    else
        log_error "✗ UI template file NOT found at backend/templates/index.html"
        return 1
    fi

    # Task 3: Jinja2 Setup
    log_info "Task 3: Verify Jinja2 Setup"
    if grep -q "Jinja2Templates" backend/main.py; then
        log_success "✓ Jinja2Templates imported in backend"
    else
        log_error "✗ Jinja2Templates NOT imported in backend"
        return 1
    fi

    # Task 4: UI Route
    log_info "Task 4: Verify Home Route"
    if grep -q '@app.get("/")' backend/main.py; then
        log_success "✓ Home route (/) defined in backend"
    else
        log_error "✗ Home route (/) NOT defined in backend"
        return 1
    fi

    # Task 5: Requirements
    log_info "Task 5: Verify Dependencies"
    if grep -q "jinja2" backend/requirements.txt; then
        log_success "✓ Jinja2 in requirements.txt"
    else
        log_error "✗ Jinja2 NOT in requirements.txt"
        return 1
    fi

    log_success "All C2 tasks verified!"
}

################################################################################
# Docker Logs Analysis
################################################################################

check_error_logs() {
    log_section "STEP 10: Checking for Errors in Logs"

    log_info "Checking Backend logs for errors..."
    if docker compose logs backend | grep -i "error\|exception" | head -5; then
        log_warning "Errors found in backend logs (see above)"
    else
        log_success "No obvious errors in backend logs"
    fi

    log_info "Checking ML Pipeline logs for errors..."
    if docker compose logs ml_pipeline | grep -i "error\|exception" | head -5; then
        log_warning "Errors found in ML Pipeline logs (see above)"
    else
        log_success "No obvious errors in ML Pipeline logs"
    fi
}

################################################################################
# Summary Report
################################################################################

generate_summary() {
    log_section "═══════════════════════════════════════════════════════════"
    log_section "END-TO-END TESTING SUMMARY"
    log_section "═══════════════════════════════════════════════════════════"

    log_info "✓ Health Checks: PASSED"
    log_info "✓ UI Serving: PASSED"
    log_info "✓ Video Upload: PASSED"
    log_info "✓ Processing: PASSED"
    log_info "✓ Results Validation: PASSED"
    log_info "✓ C2 Task Verification: PASSED"

    echo ""
    log_section "═══════════════════════════════════════════════════════════"

    log_success "ALL TESTS PASSED! 🎉"
    log_success "The V2AI system is fully functional and C2 has completed all tasks."

    echo ""
    log_info "Services Running:"
    docker compose ps

    echo ""
    log_info "To manually test the UI, open your browser:"
    log_info "  → http://localhost:8000"
}

################################################################################
# Main Execution
################################################################################

main() {
    log_section "V2AI END-TO-END TESTING"
    log_info "Starting comprehensive integration tests..."
    log_info "Timestamp: $(date)"

    # Pre-flight checks
    check_docker
    check_test_video

    # Service checks
    check_services_health
    test_health_endpoints
    test_ui_serving

    # Functional tests
    FILE_ID=$(test_video_upload)
    if [ -z "$FILE_ID" ]; then
        log_error "Failed to get FILE_ID from upload"
        exit 1
    fi

    FINAL_RESPONSE=$(test_processing_status "$FILE_ID")
    if [ $? -ne 0 ]; then
        log_error "Processing timeout or failed"
        exit 1
    fi

    validate_results "$FINAL_RESPONSE"
    if [ $? -ne 0 ]; then
        log_error "Results validation failed"
        exit 1
    fi

    # Task verification
    verify_c2_tasks
    if [ $? -ne 0 ]; then
        log_error "C2 task verification failed"
        exit 1
    fi

    # Final checks
    check_error_logs

    # Summary
    generate_summary
}

# Run main function
main
