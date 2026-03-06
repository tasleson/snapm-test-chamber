#!/bin/bash
set -e  # Exit on any error

BASE_DIR="${HOME}/VirtualMachines"

# Configuration variables
VM_NAME="fedora-vm-$(date +%s)"
VM_MEMORY=2048  # MB
VM_CPUS=2
VM_DISK_SIZE=20  # GB
BASE_IMAGE="${BASE_DIR}/images/Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2"
VM_DISK="${BASE_DIR}/auto/${VM_NAME}.qcow2"
SSH_KEY="${HOME}/.ssh/id_ed25519"
REMOTE_SCRIPT="./smoke.sh"
VM_USER="root"
VM_IP=""

echo "=== Fedora VM Provisioning Script ==="

# Create directories
mkdir -p "${BASE_DIR}/images"
mkdir -p "${BASE_DIR}/auto"

# Check prerequisites
if [ ! -f "$BASE_IMAGE" ]; then
    echo "Error: Base image not found at $BASE_IMAGE"
    exit 1
fi

if [ ! -f "$REMOTE_SCRIPT" ]; then
    echo "Error: Remote script not found at $REMOTE_SCRIPT"
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

# Copy script to VM
echo "Copying script to VM..."
scp -o StrictHostKeyChecking=no -o BatchMode=yes -i "$SSH_KEY" \
    "$REMOTE_SCRIPT" "${VM_USER}@${VM_IP}:/tmp/script-to-run.sh"

# Make script executable and run it
echo "Executing script on VM..."
ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i "$SSH_KEY" "${VM_USER}@${VM_IP}" \
    "chmod +x /tmp/script-to-run.sh && /tmp/script-to-run.sh"

echo "=== Provisioning Complete ==="
echo "VM Name: $VM_NAME"
echo "VM IP: $VM_IP"
echo "SSH Command: ssh -i $SSH_KEY ${VM_USER}@${VM_IP}"

echo ""
echo "To destroy this VM later, run:"
echo "  virsh destroy $VM_NAME && virsh undefine $VM_NAME --remove-all-storage"
