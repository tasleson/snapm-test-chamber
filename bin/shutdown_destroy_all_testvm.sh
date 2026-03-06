#!/bin/bash
# Shutdown and destroy all test VMs matching the pattern fedora-vm-*

set -e

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo "=== Test VM Cleanup Script ==="
echo ""

# Get all VMs (running and stopped) matching the pattern
TEST_VMS=$(virsh list --all --name | grep -E '^fedora-vm-[0-9]+$' || true)

if [ -z "$TEST_VMS" ]; then
    log_info "No test VMs found matching pattern 'fedora-vm-NNNNNNNNNN'"
    exit 0
fi

# Display found VMs
log_warn "Found the following test VMs:"
echo "$TEST_VMS" | while read -r vm; do
    if [ -n "$vm" ]; then
        VM_STATE=$(virsh domstate "$vm" 2>/dev/null || echo "unknown")
        echo -e "  ${BLUE}→${NC} $vm (${VM_STATE})"
    fi
done

echo ""
log_warn "This will destroy and undefine all listed VMs with storage removal."
read -p "Are you sure you want to continue? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cancelled by user"
    exit 0
fi

echo ""
log_info "Cleaning up test VMs..."

# Process each VM
DESTROYED_COUNT=0
FAILED_COUNT=0

echo "$TEST_VMS" | while read -r vm; do
    if [ -n "$vm" ]; then
        echo -e "${BLUE}Processing:${NC} $vm"

        # Destroy (force stop) if running
        if virsh destroy "$vm" 2>/dev/null; then
            echo "  ✓ Destroyed (stopped)"
        else
            echo "  • Already stopped or destroy failed"
        fi

        # Undefine and remove storage
        if virsh undefine "$vm" --remove-all-storage 2>/dev/null; then
            echo "  ✓ Undefined and storage removed"
            ((DESTROYED_COUNT++)) || true
        else
            log_error "  ✗ Failed to undefine $vm"
            ((FAILED_COUNT++)) || true
        fi

        echo ""
    fi
done

# Final summary
echo "=== Cleanup Complete ==="
log_info "Successfully cleaned: $DESTROYED_COUNT VMs"
if [ $FAILED_COUNT -gt 0 ]; then
    log_warn "Failed to clean: $FAILED_COUNT VMs"
fi
