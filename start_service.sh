#!/bin/bash
set -x
# Note: job.started and HOSTNAME markers are injected by script_submitter v4.0
# when inject_markers=true (default)
touch job.started
hostname | cut -d'.' -f1 > HOSTNAME

# Load environment and helpers
source .run.env > /dev/null 2>&1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/functions.sh"

# Defaults
export RUNMODE=${RUNMODE:-docker}
export EXAMPLE_MODE=${EXAMPLE_MODE:-curated}
export EXAMPLE_NAME=${EXAMPLE_NAME:-darcy_fno}
export DOCKER_IMAGE=${DOCKER_IMAGE:-nvcr.io/nvidia/physicsnemo/physicsnemo:25.11}
export GPU_ID=${GPU_ID:-0}
export MAX_EPOCHS=${MAX_EPOCHS:-0}
export BATCH_SIZE=${BATCH_SIZE:-0}
export CUDA_DEVICE_ORDER=PCI_BUS_ID

CONTAINER_NAME="physicsnemo-$$"

echo ""
info "Running PhysicsNemo workflow with:"
echo "  RUNMODE=$RUNMODE"
echo "  EXAMPLE_MODE=$EXAMPLE_MODE"
echo "  EXAMPLE_NAME=$EXAMPLE_NAME"
echo "  DOCKER_IMAGE=$DOCKER_IMAGE"
echo "  GPU_ID=$GPU_ID"
echo "  MAX_EPOCHS=$MAX_EPOCHS"
echo "  BATCH_SIZE=$BATCH_SIZE"
echo ""

# Create cleanup/cancel script
cat > cancel.sh << EOF
#!/bin/bash
set -x
docker rm -f ${CONTAINER_NAME} 2>/dev/null || sudo docker rm -f ${CONTAINER_NAME} 2>/dev/null || true
EOF
chmod +x cancel.sh

# Cleanup on exit
cleanup() {
    info "Cleaning up..."
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || sudo docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

# Determine docker command prefix (sudo or not)
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    if [[ "$RUNMODE" == "rootless" ]]; then
        start_rootless_docker
    elif sudo -n true 2>/dev/null; then
        sudo systemctl start docker 2>/dev/null || true
        DOCKER_CMD="sudo docker"
    else
        error "Cannot access Docker. Try rootless mode or ensure Docker is running."
        exit 1
    fi
else
    # Check if we need sudo for GPU access
    if ! docker run --rm --gpus device=0 hello-world >/dev/null 2>&1; then
        if sudo -n true 2>/dev/null; then
            DOCKER_CMD="sudo docker"
        fi
    fi
fi

# Kill any stale PhysicsNemo containers
kill_stale_containers "physicsnemo"

# Create workspace directories
mkdir -p logs workspace/outputs

# Build docker run command
DOCKER_RUN_ARGS=(
    --gpus "device=${GPU_ID}"
    --shm-size=1g
    --ulimit memlock=-1
    --ulimit stack=67108864
    --name "${CONTAINER_NAME}"
    --rm
    -e "MAX_EPOCHS=${MAX_EPOCHS}"
    -e "BATCH_SIZE=${BATCH_SIZE}"
    -e "EXAMPLE_NAME=${EXAMPLE_NAME}"
    -v "${PWD}/workspace:/workspace"
)

if [[ "$EXAMPLE_MODE" == "curated" ]]; then
    # Mount example scripts and dispatcher into container
    DOCKER_RUN_ARGS+=(
        -v "${SCRIPT_DIR}/scripts:/workspace/scripts:ro"
        -v "${SCRIPT_DIR}/examples:/workspace/examples:ro"
    )
    info "Running curated example: $EXAMPLE_NAME"
    $DOCKER_CMD run "${DOCKER_RUN_ARGS[@]}" "$DOCKER_IMAGE" \
        bash /workspace/scripts/run_example.sh 2>&1 | tee logs/training.log
else
    # Custom script mode - script is already written to workspace/custom.sh
    if [[ ! -f workspace/custom.sh ]]; then
        error "Custom script not found at workspace/custom.sh"
        exit 1
    fi
    chmod +x workspace/custom.sh
    info "Running custom script"
    $DOCKER_CMD run "${DOCKER_RUN_ARGS[@]}" "$DOCKER_IMAGE" \
        bash /workspace/custom.sh 2>&1 | tee logs/training.log
fi

EXIT_CODE=${PIPESTATUS[0]}
info "Training finished with exit code: $EXIT_CODE"

touch job.ended
exit $EXIT_CODE
