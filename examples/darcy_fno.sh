#!/bin/bash
# Darcy Flow (FNO) - Fourier Neural Operator
# Fast training, generates data on-the-fly (no external dataset needed)
# Typical runtime: ~10 min on A30 24GB
set -euo pipefail

NEMO_DIR="/workspace/PhysicsNemo"
[[ -d "$NEMO_DIR" ]] && rm -rf "$NEMO_DIR"
git clone --depth 1 https://github.com/NVIDIA/PhysicsNemo.git "$NEMO_DIR"

cd "$NEMO_DIR/examples/cfd/darcy_fno"

ARGS=""
[[ "${MAX_EPOCHS:-0}" -gt 0 ]] && ARGS="$ARGS training.max_steps=$((MAX_EPOCHS * 100))"
[[ "${BATCH_SIZE:-0}" -gt 0 ]] && ARGS="$ARGS batch_size.train=$BATCH_SIZE"

echo "=== Starting Darcy Flow FNO Training ==="
echo "  MAX_EPOCHS=${MAX_EPOCHS:-default}"
echo "  BATCH_SIZE=${BATCH_SIZE:-default}"
python -u train_fno_darcy.py $ARGS

echo "=== Training Complete ==="
cp -r outputs/* /workspace/outputs/ 2>/dev/null || true
