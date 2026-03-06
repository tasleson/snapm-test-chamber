#!/bin/bash
set -e

# Configuration
TESTBASE="${TESTBASE:-$(pwd)}"  # Default to current directory if not set
FEDORA_IMAGE_NAME="Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2"
BASE_IMAGE="${TESTBASE}/images/${FEDORA_IMAGE_NAME}"
SSH_PUB_KEY="${HOME}/.ssh/id_ed25519.pub"

# Check if base image exists
if [ ! -f "$BASE_IMAGE" ]; then
    echo "Error: Base image not found at $BASE_IMAGE"
    exit 1
fi

# Check if SSH public key exists
if [ ! -f "$SSH_PUB_KEY" ]; then
    echo "Error: SSH public key not found at $SSH_PUB_KEY"
    exit 1
fi

echo "Injecting SSH key into base image..."
virt-customize -a "$BASE_IMAGE" \
    --mkdir /root/.ssh \
    --chmod 0700:/root/.ssh \
    --upload "${SSH_PUB_KEY}:/root/.ssh/authorized_keys" \
    --chmod 0600:/root/.ssh/authorized_keys \
    --run-command 'chown -R root:root /root/.ssh' \
    --root-password password:password \
    --selinux-relabel

echo "Base image configured with SSH key for root "

