#!/bin/bash
set -e  # Exit on any error

# Track script start time
SCRIPT_START_TIME=$(date +%s)

# Configuration
TESTBASE="${TESTBASE:-$(pwd)}"  # Default to current directory if not set
IMAGES_DIR="${TESTBASE}/images"
AUTO_DIR="${TESTBASE}/auto"
FEDORA_IMAGE_NAME="Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2"
FEDORA_IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/${FEDORA_IMAGE_NAME}"
BASE_IMAGE="${IMAGES_DIR}/${FEDORA_IMAGE_NAME}"
PAYLOAD_TAR="./payload.tar.gz"

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 <snapm_source_directory>

Arguments:
  snapm_source_directory    Path to the local snapm source tree to test

Environment Variables:
  TESTBASE                  Base directory for images and VMs (default: current directory)

Example:
  $0 /path/to/snapm
  TESTBASE=/tmp/vm_tests $0 /path/to/snapm

EOF
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    log_error "Missing required argument: snapm_source_directory"
    usage
fi

SNAPM_SOURCE="$1"

# Validate snapm source directory
if [ ! -d "$SNAPM_SOURCE" ]; then
    log_error "snapm source directory not found: $SNAPM_SOURCE"
    exit 1
fi

log_info "=== Snapshot Manager VM Test Automation ==="
log_info "TESTBASE: $TESTBASE"
log_info "Images directory: $IMAGES_DIR"
log_info "VMs directory: $AUTO_DIR"
log_info "snapm source: $SNAPM_SOURCE"

# Create directories
log_info "Creating directories..."
mkdir -p "$IMAGES_DIR"
mkdir -p "$AUTO_DIR"

# Check if base image exists
IMAGE_NEEDS_SETUP=false
if [ ! -f "$BASE_IMAGE" ]; then
    log_warn "Base image not found at $BASE_IMAGE"
    log_info "Downloading Fedora Cloud Base image..."

    # Download to temporary file first
    TEMP_IMAGE="${BASE_IMAGE}.tmp"
    if curl -L -o "$TEMP_IMAGE" "$FEDORA_IMAGE_URL"; then
        mv "$TEMP_IMAGE" "$BASE_IMAGE"
        log_info "Downloaded successfully: $BASE_IMAGE"
        IMAGE_NEEDS_SETUP=true
    else
        log_error "Failed to download image from $FEDORA_IMAGE_URL"
        rm -f "$TEMP_IMAGE"
        exit 1
    fi
else
    log_info "Base image already exists: $BASE_IMAGE"
fi

# Configure base image with SSH key (only if newly downloaded)
if [ "$IMAGE_NEEDS_SETUP" = true ]; then
    log_info "Configuring base image with SSH key..."
    if ! TESTBASE="$TESTBASE" ./bin/ssh_key_inject.sh; then
        log_error "Failed to configure base image with SSH key"
        exit 1
    fi
else
    log_info "Skipping SSH key injection (base image already configured)"
fi

# Create compressed tarball of snapm source
log_info "Creating compressed tarball of snapm source..."
SNAPM_BASENAME=$(basename "$SNAPM_SOURCE")
SNAPM_PARENT=$(dirname "$SNAPM_SOURCE")

if tar -czf "$PAYLOAD_TAR" -C "$SNAPM_PARENT" "$SNAPM_BASENAME"; then
    log_info "Created payload tarball: $PAYLOAD_TAR"
else
    log_error "Failed to create tarball from $SNAPM_SOURCE"
    exit 1
fi

# Run the VM provisioning script
log_info "Starting VM provisioning and testing..."
if ! TESTBASE="$TESTBASE" ./bin/snapm_local_vm.sh; then
    log_error "VM provisioning failed"
    exit 1
fi

log_info "=== Setup and test complete ==="

# Calculate and display total time
SCRIPT_END_TIME=$(date +%s)
TOTAL_SECONDS=$((SCRIPT_END_TIME - SCRIPT_START_TIME))
MINUTES=$((TOTAL_SECONDS / 60))
SECONDS=$((TOTAL_SECONDS % 60))

echo ""
log_info "Total time: ${MINUTES}m ${SECONDS}s"
