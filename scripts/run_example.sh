#!/bin/bash
# scripts/run_example.sh - Curated example dispatcher (runs inside container)
# Sources the matching example script from /workspace/examples/
set -euo pipefail

EXAMPLE_NAME="${EXAMPLE_NAME:?EXAMPLE_NAME must be set}"
EXAMPLE_SCRIPT="/workspace/examples/${EXAMPLE_NAME}.sh"

if [[ ! -f "$EXAMPLE_SCRIPT" ]]; then
    echo "ERROR: Example script not found: $EXAMPLE_SCRIPT"
    echo "Available examples:"
    ls /workspace/examples/*.sh 2>/dev/null | sed 's|.*/||;s|\.sh$||' | while read name; do
        echo "  - $name"
    done
    exit 1
fi

# Create outputs directory
mkdir -p /workspace/outputs

echo "========================================"
echo "  PhysicsNemo Example: $EXAMPLE_NAME"
echo "========================================"
echo "  GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'unknown')"
echo "  Memory: $(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null || echo 'unknown')"
echo "  MAX_EPOCHS=${MAX_EPOCHS:-default}"
echo "  BATCH_SIZE=${BATCH_SIZE:-default}"
echo "========================================"

START_TIME=$(date +%s)

# Run the example
chmod +x "$EXAMPLE_SCRIPT"
bash "$EXAMPLE_SCRIPT"
EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "========================================"
echo "  Completed in ${DURATION}s (exit code: $EXIT_CODE)"
echo "========================================"

# Generate summary
cat > /workspace/outputs/summary.txt << EOF
Example: $EXAMPLE_NAME
Duration: ${DURATION}s
Exit Code: $EXIT_CODE
GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'unknown')
GPU Memory: $(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null || echo 'unknown')
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

# List output files
if [[ -d /workspace/outputs ]]; then
    echo "" >> /workspace/outputs/summary.txt
    echo "Output files:" >> /workspace/outputs/summary.txt
    find /workspace/outputs -type f ! -name summary.txt -printf "  %s\t%p\n" >> /workspace/outputs/summary.txt 2>/dev/null || true
fi

exit $EXIT_CODE
