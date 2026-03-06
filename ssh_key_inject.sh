#!/bin/bash
set -e

BASE_IMAGE="${HOME}/VirtualMachines/images/Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2"
SSH_PUB_KEY="${HOME}/.ssh/id_ed25519.pub"

echo "Injecting SSH key into base image..."
sudo virt-customize -a "$BASE_IMAGE" \
    --mkdir /root/.ssh \
    --chmod 0700:/root/.ssh \
    --upload "${SSH_PUB_KEY}:/root/.ssh/authorized_keys" \
    --chmod 0600:/root/.ssh/authorized_keys \
    --run-command 'chown -R root:root /root/.ssh' \
    --mkdir /home/fedora/.ssh \
    --chmod 0700:/home/fedora/.ssh \
    --upload "${SSH_PUB_KEY}:/home/fedora/.ssh/authorized_keys" \
    --chmod 0600:/home/fedora/.ssh/authorized_keys \
    --run-command 'chown -R fedora:fedora /home/fedora/.ssh' \
    --run-command 'restorecon -R /root/.ssh' \
    --run-command 'restorecon -R /home/fedora/.ssh' \
    --selinux-relabel

echo "Base image configured with SSH key for root and fedora users"

