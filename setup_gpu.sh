#!/bin/bash
# ---------------------------------------------------------
# NVIDIA GPU Setup Script (driver, CUDA toolkit, container runtime)
# ---------------------------------------------------------
# Safe to re-run: every step checks current state before changing anything.
#
# Driver notes:
# - Uses Ubuntu's archive driver + Canonical's precompiled, signed kernel
#   modules, so it loads with Secure Boot enabled and needs no MOK enrollment
#   or DKMS builds, and follows kernel upgrades automatically.
# - Always installs the "-open" kernel modules. Blackwell (RTX 50xx) and newer
#   GPUs ONLY work with the open modules; the proprietary ones fail with
#   "requires use of the NVIDIA open kernel modules" (no display, no nvidia-smi).
#   Turing and newer are all supported by the open modules.
# - The CUDA toolkit comes from NVIDIA's repo, but that repo is pinned so it can
#   never replace the Ubuntu-signed driver packages.
set -e # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration if config.env exists
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
fi

TARGET_USER="${DEV_USER:-$USER}"
# Driver branch, e.g. "595". Empty = whatever ubuntu-drivers recommends.
NVIDIA_DRIVER_BRANCH="${NVIDIA_DRIVER_BRANCH:-}"
# CUDA toolkit apt package, e.g. "cuda-toolkit-13-0". Empty = skip CUDA.
CUDA_TOOLKIT_PACKAGE="${CUDA_TOOLKIT_PACKAGE-cuda-toolkit}"

export DEBIAN_FRONTEND=noninteractive

echo "========================================================================"
echo "Setting up NVIDIA GPU for user: ${TARGET_USER}"
echo "========================================================================"

sudo apt-get install -y ubuntu-drivers-common pciutils curl gnupg

if ! lspci -d 10de: | grep -qiE "vga|3d controller"; then
    echo "No NVIDIA GPU detected on the PCI bus. Skipping GPU setup."
    exit 0
fi
lspci -d 10de: | grep -iE "vga|3d controller"

echo "--- Selecting NVIDIA driver ---"
if [ -z "${NVIDIA_DRIVER_BRANCH}" ]; then
    # e.g. "driver   : nvidia-driver-595-open - distro non-free recommended"
    NVIDIA_DRIVER_BRANCH=$(sudo ubuntu-drivers devices 2>/dev/null \
        | grep -oP 'nvidia-driver-\K[0-9]+(?=(-server)?(-open)? .*recommended)' | head -n1)
    if [ -z "${NVIDIA_DRIVER_BRANCH}" ]; then
        echo "ERROR: ubuntu-drivers did not recommend an NVIDIA driver."
        echo "Set NVIDIA_DRIVER_BRANCH in config.env (see: ubuntu-drivers devices)."
        exit 1
    fi
fi
TARGET_DRIVER="nvidia-driver-${NVIDIA_DRIVER_BRANCH}-open"
echo "Target driver: ${TARGET_DRIVER}"

echo "--- Removing other NVIDIA driver branches/flavors ---"
# Covers the proprietary (non-open) flavor that the Ubuntu installer picks by
# default, as well as other branches. Mixing them breaks module loading.
is_stale_nvidia_pkg() {
    local pkg="$1"
    [[ "${pkg}" =~ -([0-9]{3})(-|$) ]] || return 1   # not tied to a driver branch
    [ "${BASH_REMATCH[1]}" != "${NVIDIA_DRIVER_BRANCH}" ] && return 0
    case "${pkg}" in
        # Flavor-specific packages: keep only the "-open" ones.
        nvidia-driver-*|nvidia-dkms-*|nvidia-kernel-source-*|linux-modules-nvidia-*|linux-objects-nvidia-*)
            [[ "${pkg}" != *"-${NVIDIA_DRIVER_BRANCH}-open"* ]] ;;
        *) return 1 ;;
    esac
}
STALE_PKGS=""
for pkg in $(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null | awk '$1 ~ /^.i/ {print $2}' \
        | grep -E '^(nvidia-|libnvidia-|xserver-xorg-video-nvidia-|linux-(modules|objects)-nvidia-)'); do
    if is_stale_nvidia_pkg "${pkg}"; then
        STALE_PKGS="${STALE_PKGS} ${pkg}"
    fi
done
if [ -n "${STALE_PKGS}" ]; then
    echo "Purging:${STALE_PKGS}"
    sudo apt-get purge -y ${STALE_PKGS}
else
    echo "No conflicting NVIDIA driver packages installed."
fi

echo "--- Installing ${TARGET_DRIVER} (signed precompiled modules) ---"
# ubuntu-drivers pulls in the matching linux-modules-nvidia-*-open-<flavor>
# metapackage, so modules stay in sync with future kernel upgrades.
sudo ubuntu-drivers install "nvidia:${NVIDIA_DRIVER_BRANCH}-open"

# Make sure nouveau never claims the card first.
echo "blacklist nouveau
options nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null

echo "--- Enabling NVIDIA persistence daemon ---"
# Keeps the driver initialized between jobs (faster CUDA startup on headless boxes).
sudo systemctl enable nvidia-persistenced 2>/dev/null || true

echo "--- Loading driver ---"
INSTALLED_VER=$(dpkg-query -W -f='${Version}' "nvidia-utils-${NVIDIA_DRIVER_BRANCH}" 2>/dev/null | cut -d- -f1)
LOADED_VER=$(cat /sys/module/nvidia/version 2>/dev/null || true)
NEED_REBOOT=0
if [ -n "${LOADED_VER}" ] && [ "${LOADED_VER}" = "${INSTALLED_VER}" ] && nvidia-smi -L &> /dev/null; then
    echo "Driver ${LOADED_VER} already loaded and working."
elif ! modinfo -k "$(uname -r)" nvidia &> /dev/null || \
     [ "$(modinfo -k "$(uname -r)" -F version nvidia 2>/dev/null)" != "${INSTALLED_VER}" ]; then
    # Modules were built for a newer kernel (e.g. after apt upgrade).
    echo "NVIDIA ${INSTALLED_VER} modules are not available for running kernel $(uname -r)."
    NEED_REBOOT=1
else
    # Try a live swap; this works whenever no display is driven by the NVIDIA GPU.
    sudo systemctl stop nvidia-persistenced 2>/dev/null || true
    if sudo modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia 2>/dev/null || [ -z "${LOADED_VER}" ]; then
        sudo modprobe nvidia && sudo modprobe nvidia_uvm && sudo modprobe nvidia_drm || NEED_REBOOT=1
        sudo systemctl start nvidia-persistenced 2>/dev/null || true
    else
        echo "Old NVIDIA modules are in use and can't be unloaded."
        NEED_REBOOT=1
    fi
fi

if [ -n "${CUDA_TOOLKIT_PACKAGE}" ]; then
    echo "--- Installing CUDA toolkit (${CUDA_TOOLKIT_PACKAGE}) ---"
    if ! dpkg-query -W -f='${Status}' cuda-keyring 2>/dev/null | grep -q "ok installed"; then
        . /etc/os-release
        CUDA_REPO="ubuntu${VERSION_ID//./}"
        TMP_DEB=$(mktemp --suffix=.deb)
        curl -fsSL "https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_REPO}/x86_64/cuda-keyring_1.1-1_all.deb" -o "${TMP_DEB}"
        sudo dpkg -i "${TMP_DEB}"
        rm -f "${TMP_DEB}"
    fi

    # Never let NVIDIA's repo supply driver/kernel packages: those are DKMS-built
    # (unsigned -> fail under Secure Boot) and would fight the Ubuntu driver.
    # The globs match every nvidia-*/libnvidia-* package EXCEPT the
    # (lib)nvidia-container* ones: the CUDA repo also carries the container
    # toolkit with identical versions, and blocking those makes apt try to
    # "downgrade" it on every upgrade.
    cat << 'EOF' | sudo tee /etc/apt/preferences.d/cuda-repo-no-driver > /dev/null
Package: nvidia-[!c]* nvidia-c[!o]* nvidia-co[!n]* libnvidia-[!c]* libnvidia-c[!o]* libnvidia-co[!n]* cuda-drivers* xserver-xorg-video-nvidia* libxnvctrl*
Pin: origin developer.download.nvidia.com
Pin-Priority: -1
EOF

    sudo apt-get update
    sudo apt-get install -y "${CUDA_TOOLKIT_PACKAGE}"

    # Stable /etc/profile.d entry so nvcc is on PATH for every login shell.
    cat << 'EOF' | sudo tee /etc/profile.d/cuda.sh > /dev/null
if [ -d /usr/local/cuda/bin ]; then
    case ":${PATH}:" in *":/usr/local/cuda/bin:"*) ;; *) export PATH="/usr/local/cuda/bin:${PATH}" ;; esac
fi
EOF
fi

echo "--- Configuring NVIDIA Container Toolkit ---"
if command -v docker &> /dev/null; then
    if [ ! -s /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg ]; then
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
            | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    fi
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit

    if ! grep -q '"nvidia"' /etc/docker/daemon.json 2>/dev/null; then
        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl restart docker
    fi
else
    echo "Docker not installed; skipping container toolkit (run setup_docker.sh first)."
fi

echo "========================================================================"
if [ "${NEED_REBOOT}" = "1" ] || ! nvidia-smi -L &> /dev/null; then
    sudo touch /var/run/reboot-required
    echo "⚠️  GPU setup installed. REBOOT REQUIRED to load the new NVIDIA driver."
    echo "After rebooting, re-run this script (or bootstrap_machine.sh) to verify."
else
    nvidia-smi --query-gpu=name,driver_version,memory.total,pstate --format=csv
    if [ -x /usr/local/cuda/bin/nvcc ]; then
        /usr/local/cuda/bin/nvcc --version | tail -n2
    fi
    echo "🎉 NVIDIA GPU Setup Complete!"
fi
echo "========================================================================"
