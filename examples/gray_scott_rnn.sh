#!/bin/bash
# Gray-Scott RNN - 3D reaction-diffusion patterns
# Learns spatiotemporal dynamics with recurrent architecture
# Typical runtime: ~20 min on A30 24GB
set -euo pipefail

NEMO_DIR="/workspace/PhysicsNemo"
[[ -d "$NEMO_DIR" ]] && rm -rf "$NEMO_DIR"
git clone --depth 1 https://github.com/NVIDIA/PhysicsNemo.git "$NEMO_DIR"

cd "$NEMO_DIR/examples/cfd/gray_scott_rnn"

ARGS=""
[[ "${MAX_EPOCHS:-0}" -gt 0 ]] && ARGS="$ARGS training.max_steps=$((MAX_EPOCHS * 100))"
[[ "${BATCH_SIZE:-0}" -gt 0 ]] && ARGS="$ARGS batch_size=$BATCH_SIZE"

echo "=== Starting Gray-Scott RNN Training ==="
echo "  MAX_EPOCHS=${MAX_EPOCHS:-default}"
echo "  BATCH_SIZE=${BATCH_SIZE:-default}"
python -u train.py $ARGS

echo "=== Training Complete ==="
cp -r outputs/* /workspace/outputs/ 2>/dev/null || true
