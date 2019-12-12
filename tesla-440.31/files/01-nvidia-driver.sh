#!/bin/bash
set -euo pipefail

#################################################
# Settings

# A place on the host machine to cache downloads in-between reboots.

CACHE_DIR=/nvidia-device-plugin

# http://www.nvidia.com/Download/index.aspx
#
# NVIDIA driver
#
# Version:          440.31
# Release Date:     2019.11.4
# Operating System: Linux 64-bit
# Language:         English (US)
# File Size:        134.96 MB

# SUPPORTED PRODUCTS
#
# HGX-Series:
# HGX-2
#
# T-Series:
# Tesla T4
#
# V-Series:
# Tesla V100
#
# P-Series:
# Tesla P100, Tesla P40, Tesla P6, Tesla P4
#
# K-Series:
# Tesla K80, Tesla K520, Tesla K40c, Tesla K40m, Tesla K40s, Tesla K40st, Tesla K40t, Tesla K20Xm, Tesla K20m, Tesla K20s, Tesla K20c, Tesla K10, Tesla K8
#
# M-Class:
# M60, M40 24GB, M40, M6, M4

driver_file="http://us.download.nvidia.com/tesla/440.33.01/NVIDIA-Linux-x86_64-440.33.01.run"
driver_md5sum="d459669e933054d65142799b82441263"

apt-get -y update
apt-get -y install pciutils curl

#################################################
# Ensure that we are have NVIDIA GPU card in system
if [ -z "$(lspci | grep -i nvidia)" ]; then
  echo "This machine hasn't NVIDIA GPU card installed"
  echo "  Exiting without installing GPU drivers"
  exit 1
fi

#################################################
# Install dependencies

# Install GCC and linux headers on the host machine
#   The NVIDIA driver build must be compiled with the same version of GCC as
#   the kernel.  In addition, linux-headers are machine image specific.
#   Install with --no-upgrade so that the c-libs are not upgraded, possibly
#   breaking programs and requiring restart
apt-get -y --no-upgrade install gcc libc-dev linux-headers-$(uname -r)
apt-get -y clean
apt-get -y autoremove

#################################################
# Unload open-source nouveau driver if it exists
#   The nvidia drivers won't install otherwise
#   "g3" instances in particular have this module auto-loaded
modprobe -r nouveau || true

#################################################
# Download and install the Nvidia drivers

filename=$(basename $driver_file)
filepath="${CACHE_DIR}/${filename}"
filepath_installed="${CACHE_DIR}/${filename}.installed"

# Install the Nvidia driver
if [[ -f $filepath_installed ]]; then
    echo "Detected prior install of file $filename on host"
else
    echo "Checking for file at $filepath"
    if [[ ! -f $filepath ]] || ! (echo "$driver_md5sum  $filepath" | md5sum -c - 2>&1 >/dev/null); then
        echo "Downloading $driver_file"
        curl -L $driver_file -o $filepath
        chmod a+x $filepath
    fi

    echo "Verifying md5sum of file at $filepath"
    if ! (echo "$driver_md5sum  $filepath" | md5sum -c -); then
      echo "Failed to verify md5sum for file at $filepath"
      exit 1
    fi

    echo "Installing file $filename on host"
    $filepath --accept-license --silent
    touch $filepath_installed # Mark successful installation
fi

#################################################
# Output GPU info for debugging
nvidia-smi --list-gpus

#################################################
# Configure and Optimize Nvidia cards now that things are installed
#   AWS Optimizization Doc
#     https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/optimize_gpu.html
#   Nvidia Doc
#     http://developer.download.nvidia.com/compute/DCGM/docs/nvidia-smi-367.38.pdf

# Common configurations
nvidia-smi -pm 1
nvidia-smi --auto-boost-default=0
nvidia-smi --auto-boost-permission=0

# Custom configurations per AWS instance type of nvidia video card
case "$(curl -m 2 -fsL http://169.254.169.254/latest/meta-data/instance-type | cut -d . -f 1 || true)" in
"g3" | "g3s")
  nvidia-smi -ac 2505,1177
  ;;
"g4dn")
  nvidia-smi -ac 5001,1590
  ;;
"p2")
  nvidia-smi -ac 2505,875
  nvidia-smi -acp 0
  ;;
"p3" | "p3dn")
  nvidia-smi -ac 877,1530
  nvidia-smi -acp 0
  ;;
*)
  ;;
esac

#################################################
# Load the Kernel Module

if ! /sbin/modprobe nvidia-uvm; then
  echo "Unable to modprobe nvidia-uvm"
  exit 1
fi

# Ensure that the device node exists
if ! test -e /dev/nvidia-uvm; then
  # Find out the major device number used by the nvidia-uvm driver
  D=`grep nvidia-uvm /proc/devices | awk '{print $1}'`
  mknod -m 666 /dev/nvidia-uvm c $D 0
fi
