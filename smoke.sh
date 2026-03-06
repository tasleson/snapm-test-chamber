#!/bin/bash
# smoke.sh

echo "=== Running on VM ==="
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime)"

# Example: Install packages
sudo dnf install -y python3 python3-pip


echo "=== Script execution complete ==="

