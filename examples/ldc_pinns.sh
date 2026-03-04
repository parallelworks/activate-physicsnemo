#!/bin/bash
# Lid-Driven Cavity (PINNs) - Physics-Informed Neural Network
# Pure physics-based, no external data needed
# Typical runtime: ~15 min on A30 24GB
set -euo pipefail

NEMO_DIR="/workspace/PhysicsNemo"
[[ -d "$NEMO_DIR" ]] && rm -rf "$NEMO_DIR"
git clone --depth 1 https://github.com/NVIDIA/PhysicsNemo.git "$NEMO_DIR"

cd "$NEMO_DIR/examples/cfd/ldc_pinns"

ARGS=""
[[ "${MAX_EPOCHS:-0}" -gt 0 ]] && ARGS="$ARGS training.max_steps=$((MAX_EPOCHS * 100))"
[[ "${BATCH_SIZE:-0}" -gt 0 ]] && ARGS="$ARGS batch_size=$BATCH_SIZE"

echo "=== Starting Lid-Driven Cavity PINNs Training ==="
echo "  MAX_EPOCHS=${MAX_EPOCHS:-default}"
echo "  BATCH_SIZE=${BATCH_SIZE:-default}"
python -u train.py $ARGS

echo "=== Training Complete ==="
cp -r outputs/* /workspace/outputs/ 2>/dev/null || true
