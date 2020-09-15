#!/bin/bash
set -euo pipefail

# Copy the setup scripts to the host
#   The kops hook automatically mounts the host root filesystem into the
#   container /rootfs
mkdir -p /rootfs/nvidia-device-plugin
cp -r /nvidia-device-plugin/* /rootfs/nvidia-device-plugin

# Setup the host systemd to run the systemd unit that runs setup scripts
ln -sf /nvidia-device-plugin/nvidia-device-plugin.service /rootfs/etc/systemd/system/nvidia-device-plugin.service

# Save the environment to be passed on to the systemd unit
(env | grep NVIDIA_DEVICE_PLUGIN > /rootfs/nvidia-device-plugin/environment) || true

# Kickoff host systemd unit that runs the setup scripts
#   'systemctl' within this docker container uses the mounted /run/systemd/*
#   volume from the host to control systemd on the host.
systemctl daemon-reload
systemctl start --no-block nvidia-device-plugin.service

exit 0
