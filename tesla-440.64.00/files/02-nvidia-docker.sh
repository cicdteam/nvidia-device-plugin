#!/bin/bash
set -euo pipefail

# Add the package repositories
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Override the default runtime with the one from nvidia
cat << 'EOF' > /etc/docker/daemon.json
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF

# Stop kubelet to ensure not bring stopped containers up again and leak
# them as orphan containers
systemctl stop kubelet

apt-get update
apt-get install -y nvidia-container-runtime
systemctl restart docker

# Disable a few things that break docker-ce/gpu support upon reboot:
#  Upon boot, the kops-configuration.service systemd unit sets up and starts
#  the cloud-init.service which runs nodeup which forces docker-ce to a
#  specific version that is a downgrade and incompatible with nvidia-docker2.
#  Permanently disable these systemd units via masking.
systemctl mask cloud-init.service
systemctl mask kops-configuration.service

# Restore protokube and protokube will bring up kubelet
#systemctl start protokube
systemctl start kubelet
