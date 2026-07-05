#!/bin/bash
set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
else
    echo "Error: config.env not found. Please copy config.env.example to config.env and fill it out."
    exit 1
fi

if [ -z "${ZEROTIER_NETWORK_ID}" ]; then
    echo "No ZeroTier network ID provided in config.env. Skipping ZeroTier join."
    exit 0
fi

# Install ZeroTier if not present
if ! command -v zerotier-cli &> /dev/null; then
    echo "Installing ZeroTier..."
    curl -s https://install.zerotier.com | sudo bash
fi

echo "Joining ZeroTier network: ${ZEROTIER_NETWORK_ID}..."
sudo zerotier-cli join "${ZEROTIER_NETWORK_ID}"
