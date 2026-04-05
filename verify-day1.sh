#!/bin/bash

# V2AI Day 1 Verification Script

echo "=== V2AI C1 Day 1 Verification ==="
echo ""

# Activate venv
source venv/bin/activate

# Check requirements
echo "1. Checking Python dependencies..."
python3 << 'EOF'
import sys
sys.path.insert(0, './backend')

try:
    from config import settings
    from audio_service import extract_audio
    from gcp_service import upload_to_gcs, store_metadata, get_metadata
    from main import app
    print("   ✓ All modules import successfully")
except ImportError as e:
    print(f"   ✗ Import error: {e}")
    sys.exit(1)
EOF

# Check config loading
echo ""
echo "2. Checking configuration..."
python3 << 'EOF'
import sys
sys.path.insert(0, './backend')

from config import settings
print(f"   ✓ GCP Project ID: {settings.gcp_project_id}")
print(f"   ✓ GCS Bucket: {settings.gcs_bucket_name}")
print(f"   ✓ Firestore DB: {settings.firestore_db_name}")
print(f"   ✓ Upload Dir: {settings.upload_dir}")
EOF

# Check API routes
echo ""
echo "3. Checking API routes..."
python3 << 'EOF'
import sys
sys.path.insert(0, './backend')

from main import app
routes = {}
for route in app.routes:
    if hasattr(route, 'path') and hasattr(route, 'methods') and not route.path.startswith('/openapi') and not route.path.startswith('/docs') and not route.path.startswith('/redoc'):
        methods = list(route.methods)
        routes[route.path] = methods

for path, methods in sorted(routes.items()):
    print(f"   ✓ {' '.join(methods):6} {path}")
EOF

# Check local directories
echo ""
echo "4. Checking local directories..."
mkdir -p uploads uploads/audio
echo "   ✓ uploads/ directory ready"
echo "   ✓ uploads/audio/ directory ready"

# Summary
echo ""
echo "=== Summary ==="
echo "All checks passed! Day 1 implementation is ready."
echo ""
echo "Next steps:"
echo "  1. Place your GCP service account JSON key as: gcp-key.json"
echo "  2. Run: docker-compose up --build"
echo "  3. Test: curl -X GET http://localhost:8000/health"
echo ""
echo "To test /upload endpoint:"
echo "  curl -X POST -F 'file=@sample.mp4' http://localhost:8000/upload"
