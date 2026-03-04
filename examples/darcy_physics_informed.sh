#!/bin/bash
# Darcy Flow (PINO) - Physics-Informed Neural Operator
# Combines data-driven and physics losses
# Typical runtime: ~15 min on A30 24GB
set -euo pipefail

NEMO_DIR="/workspace/PhysicsNemo"
[[ -d "$NEMO_DIR" ]] && rm -rf "$NEMO_DIR"
git clone --depth 1 --branch v1.1.0 https://github.com/NVIDIA/PhysicsNemo.git "$NEMO_DIR"

cd "$NEMO_DIR/examples/cfd/darcy_physics_informed"

ARGS=""
[[ "${MAX_EPOCHS:-0}" -gt 0 ]] && ARGS="$ARGS training.max_steps=$((MAX_EPOCHS * 100))"
[[ "${BATCH_SIZE:-0}" -gt 0 ]] && ARGS="$ARGS batch_size.train=$BATCH_SIZE"

echo "=== Starting Darcy Flow Physics-Informed Training ==="
echo "  MAX_EPOCHS=${MAX_EPOCHS:-default}"
echo "  BATCH_SIZE=${BATCH_SIZE:-default}"
python -u train_fno_darcy.py $ARGS

echo "=== Training Complete ==="
cp -r outputs/* /workspace/outputs/ 2>/dev/null || true
