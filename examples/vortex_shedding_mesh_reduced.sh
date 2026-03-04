#!/bin/bash
# Vortex Shedding (MeshGraphNet) - Reduced mesh graph neural network
# Learns flow around a cylinder with animated output
# Typical runtime: ~25 min on A30 24GB
set -euo pipefail

NEMO_DIR="/workspace/PhysicsNemo"
[[ -d "$NEMO_DIR" ]] && rm -rf "$NEMO_DIR"
git clone --depth 1 --branch v1.1.0 https://github.com/NVIDIA/PhysicsNemo.git "$NEMO_DIR"

cd "$NEMO_DIR/examples/cfd/vortex_shedding_mesh_reduced"

ARGS=""
[[ "${MAX_EPOCHS:-0}" -gt 0 ]] && ARGS="$ARGS training.max_steps=$((MAX_EPOCHS * 100))"
[[ "${BATCH_SIZE:-0}" -gt 0 ]] && ARGS="$ARGS batch_size=$BATCH_SIZE"

echo "=== Starting Vortex Shedding MeshGraphNet Training ==="
echo "  MAX_EPOCHS=${MAX_EPOCHS:-default}"
echo "  BATCH_SIZE=${BATCH_SIZE:-default}"
python -u train.py $ARGS

echo "=== Training Complete ==="
cp -r outputs/* /workspace/outputs/ 2>/dev/null || true
