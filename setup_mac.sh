#!/bin/bash
# Bootstrap a fresh macOS machine for a non-developer user:
#   - Installs the Claude desktop app and Claude Code CLI (the user signs in themselves)
#   - Installs ZeroTier, applies the IPv6 transport blacklist, and joins the network
#
# No Homebrew / Xcode CLT required; only uses tools that ship with macOS.
#
# Usage:
#   bash setup_mac.sh [ZEROTIER_NETWORK_ID]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
fi
ZEROTIER_NETWORK_ID="${1:-${ZEROTIER_NETWORK_ID:-f3797ba7a8546f34}}"

if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: setup_mac.sh is for macOS only."
    exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

# Ask for sudo up front and keep it alive for the duration of the script
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &

# 1. Claude desktop app
if [ -d "/Applications/Claude.app" ]; then
    echo "Claude desktop app is already installed."
else
    echo "Downloading Claude desktop app..."
    if curl -fsL -o "${WORK_DIR}/Claude.dmg" "https://claude.ai/api/desktop/darwin/universal/dmg/latest/redirect"; then
        MOUNT_POINT="${WORK_DIR}/claude_mount"
        mkdir -p "${MOUNT_POINT}"
        hdiutil attach -nobrowse -quiet -mountpoint "${MOUNT_POINT}" "${WORK_DIR}/Claude.dmg"
        echo "Installing Claude to /Applications..."
        sudo ditto "${MOUNT_POINT}/Claude.app" "/Applications/Claude.app"
        hdiutil detach -quiet "${MOUNT_POINT}"
    else
        # claude.ai's dmg link sits behind a bot check that blocks curl; fall back to the auto-update feed
        echo "DMG link blocked; using the Claude auto-update feed instead..."
        ZIP_URL="$(curl -fsL "https://downloads.claude.ai/releases/darwin/universal/RELEASES.json" \
            | /usr/bin/plutil -extract releases.0.updateTo.url raw -o - -)"
        curl -fL -o "${WORK_DIR}/Claude.zip" "${ZIP_URL}"
        ditto -x -k "${WORK_DIR}/Claude.zip" "${WORK_DIR}/claude_unzip"
        echo "Installing Claude to /Applications..."
        sudo ditto "${WORK_DIR}/claude_unzip/Claude.app" "/Applications/Claude.app"
    fi
fi

# 2. Claude Code CLI (claude)
if [ -x "${HOME}/.local/bin/claude" ] || command -v claude &> /dev/null; then
    echo "Claude Code (claude) is already installed."
else
    echo "Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
fi
# macOS defaults to zsh, and ~/.local/bin is not on its PATH
if ! grep -qs '.local/bin' "${HOME}/.zshrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.zshrc"
fi

# 3. ZeroTier
ZT_CLI="/usr/local/bin/zerotier-cli"
ZT_HOME="/Library/Application Support/ZeroTier/One"
if [ -x "${ZT_CLI}" ]; then
    echo "ZeroTier is already installed."
else
    echo "Downloading ZeroTier..."
    curl -fL -o "${WORK_DIR}/ZeroTier.pkg" "https://download.zerotier.com/dist/ZeroTier%20One.pkg"
    echo "Installing ZeroTier..."
    sudo installer -pkg "${WORK_DIR}/ZeroTier.pkg" -target /
fi

# Same IPv6 transport blacklist as zerotier.sh uses on Linux
echo "Configuring ZeroTier local.conf to blacklist physical IPv6 paths..."
sudo mkdir -p "${ZT_HOME}"
cat << 'EOF' | sudo tee "${ZT_HOME}/local.conf" > /dev/null
{
  "physical": {
    "::/0": {
      "blacklist": true
    }
  }
}
EOF

echo "Restarting ZeroTier service to apply local.conf changes..."
sudo launchctl kickstart -k system/com.zerotier.one 2>/dev/null || {
    sudo launchctl unload /Library/LaunchDaemons/com.zerotier.one.plist 2>/dev/null || true
    sudo launchctl load /Library/LaunchDaemons/com.zerotier.one.plist
}

echo "Joining ZeroTier network: ${ZEROTIER_NETWORK_ID}..."
for i in {1..10}; do
    if sudo "${ZT_CLI}" join "${ZEROTIER_NETWORK_ID}"; then
        echo "Successfully requested join!"
        break
    fi
    echo "ZeroTier daemon may still be starting. Retrying in 2 seconds... (attempt $i/10)"
    sleep 2
done

NODE_ID="$(sudo "${ZT_CLI}" info | awk '{print $3}')"
echo
echo "=================================================================="
echo " Done."
echo
echo " ZeroTier Node ID: ${NODE_ID}"
echo " Authorize it at https://my.zerotier.com -> network ${ZEROTIER_NETWORK_ID}"
echo " -> Members -> check 'Auth'. Then verify with:"
echo "     sudo zerotier-cli listnetworks"
echo
echo " Open Claude from /Applications (or run claude in a new Terminal) and sign in"
echo " with the user's own account."
echo "=================================================================="
