#<img width="800" height="600" alt="snapm-test-chamber" src="https://github.com/user-attachments/assets/2de8499b-67aa-43ef-bb5a-70c1671beaf3" />

Automated testing framework for [snapm](https://github.com/snapshotmanager/snapm) using disposable Fedora VMs. Handles image download, VM provisioning, dependency installation, and pytest execution in clean isolated environments.

## Prerequisites

```bash
sudo dnf install -y libvirt qemu-kvm virt-install libguestfs-tools
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```

Requires SSH key at `~/.ssh/id_ed25519` and 20GB+ disk space per VM.

## Usage

```bash
# Basic usage
./setup_and_test.sh /path/to/snapm

# Custom location for images and VMs
TESTBASE=/tmp/vm_tests ./setup_and_test.sh /path/to/snapm
```

## How It Works

1. Downloads Fedora 43 Cloud Base image (if needed) and injects SSH key
2. Creates VM, uploads snapm source tarball
3. Installs dependencies, configures snapm, runs pytest
4. Generates cleanup script: `./cleanup_fedora-vm-<timestamp>.sh`

## Cleanup

```bash
./cleanup_fedora-vm-1234567890.sh
```

## Troubleshooting

- **SSH fails**: `virsh net-start default` or check `virsh console <vm-name>`
- **No IP**: Restart libvirtd
- **Disk space**: Clean up `auto/` and `images/` directories
