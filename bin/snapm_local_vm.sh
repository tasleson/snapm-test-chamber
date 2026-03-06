#!/bin/bash
set -e  # Exit on any error

# Configuration
TESTBASE="${TESTBASE:-$(pwd)}"  # Default to current directory if not set
IMAGES_DIR="${TESTBASE}/images"
AUTO_DIR="${TESTBASE}/auto"
FEDORA_IMAGE_NAME="Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2"

# Configuration variables
VM_NAME="fedora-vm-$(date +%s)"
VM_MEMORY=2048  # MB
VM_CPUS=2
VM_DISK_SIZE=20  # GB
BASE_IMAGE="${IMAGES_DIR}/${FEDORA_IMAGE_NAME}"
VM_DISK="${AUTO_DIR}/${VM_NAME}.qcow2"
SSH_KEY="${HOME}/.ssh/id_ed25519"
TAR_FILE="./payload.tar.gz"  # Compressed tar file to upload
VM_USER="root"
VM_IP=""

echo "=== Fedora VM Provisioning Script ==="
echo "TESTBASE: $TESTBASE"
echo "Images directory: $IMAGES_DIR"
echo "VMs directory: $AUTO_DIR"

# Create directories
mkdir -p "$IMAGES_DIR"
mkdir -p "$AUTO_DIR"

# Check prerequisites
if [ ! -f "$BASE_IMAGE" ]; then
    echo "Error: Base image not found at $BASE_IMAGE"
    exit 1
fi

if [ ! -f "$TAR_FILE" ]; then
    echo "Error: Tar file not found at $TAR_FILE"
    exit 1
fi

if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key not found at $SSH_KEY"
    exit 1
fi

# Create VM disk from base image
echo "Creating VM disk from base image..."
qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$VM_DISK" "${VM_DISK_SIZE}G"

# Create and start the VM
echo "Creating VM: $VM_NAME"
virt-install \
    --name "$VM_NAME" \
    --memory "$VM_MEMORY" \
    --vcpus "$VM_CPUS" \
    --disk path="$VM_DISK",format=qcow2 \
    --os-variant fedora43 \
    --network network=default \
    --graphics none \
    --console pty,target_type=serial \
    --import \
    --noautoconsole

echo "VM created and starting..."

# Create cleanup script immediately so user can clean up if something fails
CLEANUP_SCRIPT="${TESTBASE}/cleanup_${VM_NAME}.sh"
cat > "$CLEANUP_SCRIPT" << 'CLEANUP_EOF'
#!/bin/bash
# Cleanup script for VM: $VM_NAME
SCRIPT_PATH="$(readlink -f "$0")"
virsh destroy $VM_NAME && virsh undefine $VM_NAME --remove-all-storage
rm -f "$SCRIPT_PATH"
CLEANUP_EOF
# Replace VM_NAME placeholder in the script
sed -i "s/\$VM_NAME/$VM_NAME/g" "$CLEANUP_SCRIPT"
chmod +x "$CLEANUP_SCRIPT"
echo "Cleanup script created: $CLEANUP_SCRIPT"

# Wait for VM to boot and get IP
echo "Waiting for VM to get an IP address..."
IP_FOUND=false
for i in {1..60}; do
    VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -1)
    if [ -n "$VM_IP" ]; then
        echo "VM IP address: $VM_IP (attempt $i)"
        IP_FOUND=true
        break
    fi
    sleep 5
done

if [ "$IP_FOUND" = false ]; then
    echo "Error: Could not determine VM IP address after 5 minutes"
    exit 1
fi

# Wait for SSH to be available
echo "Waiting for SSH service to be ready..."
SSH_READY=false
for i in {1..30}; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
        -i "$SSH_KEY" "${VM_USER}@${VM_IP}" "echo 'SSH ready'" 2>/dev/null; then
        echo "SSH connection successful! (took $i attempts)"
        SSH_READY=true
        break
    fi
    sleep 5
done

if [ "$SSH_READY" = false ]; then
    echo "Error: SSH service did not become available after 2.5 minutes"
    exit 1
fi

# Copy tar file to VM
echo "Uploading tar file to VM..."
scp -o StrictHostKeyChecking=no -o BatchMode=yes -i "$SSH_KEY" \
    "$TAR_FILE" "${VM_USER}@${VM_IP}:/root/payload.tar.gz"

# Execute test setup and run tests
echo "Setting up test environment and running tests..."
ssh -t -o StrictHostKeyChecking=no -o BatchMode=yes -i "$SSH_KEY" "${VM_USER}@${VM_IP}" << 'EOF'
set -e  # Exit on error
set -x  # Show commands being executed

# Create test directory and change to it
mkdir -p /root/test
cd /root/test

# Install git
dnf install -y git

# Clone boom-boot repository
git clone https://github.com/snapshotmanager/boom-boot

# Extract payload and capture the created directory
tar -xzf /root/payload.tar.gz
TESTING=$(tar -tzf /root/payload.tar.gz | head -1 | cut -f1 -d"/")

# Install build dependencies for snapm
dnf -y builddep snapm

# Enable and start stratisd
systemctl enable --now stratisd

# Change to testing directory
cd "$TESTING"

# Install configuration files and systemd units
cp -r etc/snapm /etc
cp systemd/*.timer systemd/*.service /usr/lib/systemd/system
cp systemd/tmpfiles.d/snapm.conf /usr/lib/tmpfiles.d
systemd-tmpfiles --create /usr/lib/tmpfiles.d/snapm.conf
systemctl daemon-reload

# Source environment setup script
. scripts/setpaths.sh

# Run pytest
pytest -v --log-level=debug --color=yes tests/
EOF

echo "=== Provisioning Complete ==="
echo "VM Name: $VM_NAME"
echo "VM IP: $VM_IP"
echo "SSH Command: ssh -i $SSH_KEY ${VM_USER}@${VM_IP}"

echo ""
echo "To destroy this VM later, run:"
echo " $CLEANUP_SCRIPT"
echo "  or manually: virsh destroy $VM_NAME && virsh undefine $VM_NAME --remove-all-storage"
