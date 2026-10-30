#!/bin/bash
# ---------------------------------------------------------
# Docker Engine Setup Script (official Docker apt repository)
# ---------------------------------------------------------
set -e # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration if config.env exists
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
fi

TARGET_USER="${DEV_USER:-$USER}"

echo "========================================================================"
echo "Setting up Docker Engine for user: ${TARGET_USER}"
echo "========================================================================"

# Remove conflicting distro packages (no-op if absent)
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    if dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "ok installed"; then
        sudo apt-get remove -y "${pkg}"
    fi
done

sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -s /etc/apt/keyrings/docker.asc ]; then
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
fi
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker

# Allow running docker without sudo (takes effect after re-login)
sudo usermod -aG docker "${TARGET_USER}"

echo "========================================================================"
echo "🎉 Docker Setup Complete! $(docker --version)"
echo "========================================================================"
