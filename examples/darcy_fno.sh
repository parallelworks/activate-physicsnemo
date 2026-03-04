#!/bin/bash
# Darcy Flow (FNO) - Fourier Neural Operator
# Fast training, generates data on-the-fly (no external dataset needed)
# Typical runtime: ~30 min on A30 24GB (20 pseudo-epochs)
set -euo pipefail

NEMO_DIR="/workspace/PhysicsNemo"
[[ -d "$NEMO_DIR" ]] && rm -rf "$NEMO_DIR"
git clone --depth 1 --branch v1.1.0 https://github.com/NVIDIA/PhysicsNemo.git "$NEMO_DIR"

cd "$NEMO_DIR/examples/cfd/darcy_fno"

# Default to 20 pseudo-epochs for a reasonable demo runtime (~30 min on A30)
# Original default is 256 which takes ~6 hours
DEFAULT_EPOCHS=20
EPOCHS=${MAX_EPOCHS:-$DEFAULT_EPOCHS}
[[ "$EPOCHS" -eq 0 ]] && EPOCHS=$DEFAULT_EPOCHS

ARGS="training.max_pseudo_epochs=$EPOCHS"
[[ "${BATCH_SIZE:-0}" -gt 0 ]] && ARGS="$ARGS training.batch_size=$BATCH_SIZE"

echo "=== Starting Darcy Flow FNO Training ==="
echo "  EPOCHS=$EPOCHS"
echo "  BATCH_SIZE=${BATCH_SIZE:-default (64)}"
python -u train_fno_darcy.py $ARGS

echo "=== Training Complete ==="
cp -r outputs/* /workspace/outputs/ 2>/dev/null || true
