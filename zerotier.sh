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

echo "Configuring ZeroTier local.conf to blacklist physical IPv6 paths..."
sudo mkdir -p /var/lib/zerotier-one
cat << 'EOF' | sudo tee /var/lib/zerotier-one/local.conf > /dev/null
{
  "physical": {
    "::/0": {
      "blacklist": true
    }
  }
}
EOF

echo "Restarting ZeroTier service to apply local.conf changes..."
sudo systemctl restart zerotier-one

echo "Installing NetworkManager dispatcher script for ZeroTier MTU clamping..."
sudo mkdir -p /etc/NetworkManager/dispatcher.d
cat << 'EOF' | sudo tee /etc/NetworkManager/dispatcher.d/99-zerotier-mtu.sh > /dev/null
#!/bin/bash

# NetworkManager dispatcher script to clamp ZeroTier interface MTU to 1300.
INTERFACE=$1
ACTION=$2

if [[ "$INTERFACE" =~ ^zt ]]; then
    # ZeroTier might configure the interface and reset the MTU after it comes up.
    # We run in the background and wait 2 seconds before clamping the MTU.
    (
        sleep 2
        ip link set dev "$INTERFACE" mtu 1300
    ) &
fi
EOF

sudo chmod 755 /etc/NetworkManager/dispatcher.d/99-zerotier-mtu.sh
sudo chown root:root /etc/NetworkManager/dispatcher.d/99-zerotier-mtu.sh

echo "Joining ZeroTier network: ${ZEROTIER_NETWORK_ID}..."
sudo zerotier-cli join "${ZEROTIER_NETWORK_ID}"

# Immediately apply MTU clamp to existing ZeroTier interfaces
echo "Applying MTU clamp to any active ZeroTier interfaces..."
for dev in $(ip -o link show | awk -F': ' '{print $2}' | grep '^zt'); do
    echo "Clamping MTU on $dev to 1300..."
    sudo ip link set dev "$dev" mtu 1300 || true
done

