#!/bin/bash
# lib/functions.sh - Common functions for ACTIVATE PhysicsNemo
# Source this file in other scripts: source "$(dirname "$0")/lib/functions.sh"

set -o pipefail

# ============================================================================
# Logging Configuration
# ============================================================================

LOG_DIR="${LOG_DIR:-./logs}"
LOG_FILE="${LOG_DIR}/physicsnemo-$(date +%Y%m%d-%H%M%S).log"
DEBUG="${DEBUG:-0}"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR" 2>/dev/null || true

# ============================================================================
# Logging Functions
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Color codes for terminal output
    local color_reset="\033[0m"
    local color=""
    case "$level" in
        INFO)  color="\033[0;32m" ;;  # Green
        WARN)  color="\033[0;33m" ;;  # Yellow
        ERROR) color="\033[0;31m" ;;  # Red
        DEBUG) color="\033[0;36m" ;;  # Cyan
    esac

    # Log to file (without colors)
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true

    # Log to terminal (with colors if interactive)
    if [[ -t 1 ]]; then
        echo -e "${color}[$timestamp] [$level]${color_reset} $message"
    else
        echo "[$timestamp] [$level] $message"
    fi
}

info()  { log "INFO" "$@"; }
warn()  { log "WARN" "$@" >&2; }
error() { log "ERROR" "$@" >&2; }
debug() { [[ "${DEBUG}" == "1" ]] && log "DEBUG" "$@"; }

# ============================================================================
# GPU Detection
# ============================================================================

detect_gpu_count() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi -L 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

get_gpu_free_memory() {
    # Returns free memory in MiB for given GPU ID (default 0)
    local gpu_id="${1:-0}"
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits -i "$gpu_id" 2>/dev/null | tr -d ' '
    else
        echo "0"
    fi
}

get_gpu_name() {
    local gpu_id="${1:-0}"
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=name --format=csv,noheader -i "$gpu_id" 2>/dev/null | tr -d '\n'
    else
        echo "unknown"
    fi
}

# ============================================================================
# Docker Helpers
# ============================================================================

start_rootless_docker() {
    local MAX_RETRIES=20
    local RETRY_INTERVAL=2
    local ATTEMPT=1

    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    dockerd-rootless-setuptool.sh install

    if command -v screen >/dev/null 2>&1; then
        info "Starting Docker rootless daemon in a screen session..."
        screen -dmS docker-rootless bash -c "PATH=/usr/bin:/sbin:/usr/sbin:\$PATH dockerd-rootless.sh --exec-opt native.cgroupdriver=cgroupfs > ~/docker-rootless.log 2>&1"
    else
        info "Starting Docker rootless daemon in background..."
        PATH=/usr/bin:/sbin:/usr/sbin:$PATH dockerd-rootless.sh --exec-opt native.cgroupdriver=cgroupfs > ~/docker-rootless.log 2>&1 &
    fi

    until docker info > /dev/null 2>&1; do
        if [ $ATTEMPT -le $MAX_RETRIES ]; then
            info "Attempt $ATTEMPT of $MAX_RETRIES: Waiting for Docker daemon to start..."
            sleep $RETRY_INTERVAL
            ((ATTEMPT++))
        else
            error "Docker daemon failed to start after $MAX_RETRIES attempts."
            return 1
        fi
    done

    info "Docker daemon is ready!"
    return 0
}

ensure_docker_running() {
    local runmode="${1:-docker}"

    which docker >/dev/null 2>&1 || {
        error "Docker is not installed."
        return 1
    }

    docker ps >/dev/null 2>&1
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        info "Docker is accessible"
    elif [[ "$runmode" == "rootless" ]]; then
        start_rootless_docker
    elif sudo -n true 2>/dev/null; then
        sudo systemctl start docker 2>/dev/null || true
        # Verify docker is now accessible with sudo
        sudo docker ps >/dev/null 2>&1 || {
            error "Failed to start Docker with sudo"
            return 1
        }
    else
        error "Cannot access Docker. Try rootless mode or ensure Docker is running."
        return 1
    fi
    return 0
}

kill_stale_containers() {
    # Kill any running PhysicsNemo containers
    local pattern="${1:-physicsnemo}"
    local containers
    containers=$(docker ps -q --filter "name=$pattern" 2>/dev/null || sudo docker ps -q --filter "name=$pattern" 2>/dev/null || true)
    if [[ -n "$containers" ]]; then
        warn "Killing stale containers matching '$pattern': $containers"
        docker rm -f $containers 2>/dev/null || sudo docker rm -f $containers 2>/dev/null || true
    fi
}

# ============================================================================
# Cleanup Functions
# ============================================================================

cleanup_on_exit() {
    local exit_code=$?

    if (( exit_code != 0 )); then
        error "Script failed with exit code: $exit_code"
    fi

    # Run cancel script if it exists
    if [[ -x "./cancel.sh" ]]; then
        debug "Running cleanup via cancel.sh"
        ./cancel.sh 2>/dev/null || true
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command not found: $cmd"
        [[ -n "$install_hint" ]] && error "Install hint: $install_hint"
        return 1
    fi
    return 0
}

validate_required_vars() {
    local missing=()

    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        error "Missing required environment variables: ${missing[*]}"
        return 1
    fi
    return 0
}
