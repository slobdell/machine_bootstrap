#!/bin/bash
# ---------------------------------------------------------
# Machine Bootstrap Master Script
# ---------------------------------------------------------
set -e # Exit on error

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "${SCRIPT_DIR}/config.env" ]; then
    echo "========================================================================"
    echo "ERROR: config.env not found!"
    echo "Please copy config.env.example to config.env and fill out your configurations."
    echo "Example:"
    echo "  cp config.env.example config.env"
    echo "  vim config.env"
    echo "========================================================================"
    exit 1
fi
source "${SCRIPT_DIR}/config.env"

# Determine target user and home directory
TARGET_USER="${DEV_USER:-$USER}"
TARGET_HOME=$(eval echo "~${TARGET_USER}")

echo "========================================================================"
echo "Starting Machine Bootstrap for user: ${TARGET_USER}"
echo "Home Directory: ${TARGET_HOME}"
echo "========================================================================"

echo "--- Creating Projects Directory ---"
mkdir -p "${TARGET_HOME}/projects"

# Clean up any potential broken repository files from previous runs
# (e.g., empty GPG key file or bad sources list)
if [ ! -f /usr/share/keyrings/githubcli-archive-keyring.gpg ] || [ ! -s /usr/share/keyrings/githubcli-archive-keyring.gpg ]; then
    echo "Cleaning up potential broken GitHub CLI repository config..."
    sudo rm -f /etc/apt/sources.list.d/github-cli.list
    sudo rm -f /usr/share/keyrings/githubcli-archive-keyring.gpg
fi

# Add repository for latest git version
sudo add-apt-repository ppa:git-core/ppa -y

# Add repository for GitHub CLI (gh)
if ! command -v gh &> /dev/null; then
    echo "Adding repository for GitHub CLI..."
    # Ensure curl and gnupg are installed first
    sudo apt update && sudo apt install -y curl gnupg
    
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
fi

echo "--- Initializing System Update ---"
sudo apt update && sudo apt upgrade -y

echo "--- Installing software-properties-common ---"
sudo apt install -y software-properties-common

echo "--- Installing Standard Dev Tools ---"
sudo apt install -y \
    build-essential \
    cmake \
    git \
    git-lfs \
    gh \
    vim \
    screen \
    curl \
    wget \
    htop \
    tree \
    xclip \
    ffmpeg \
    net-tools \
    ripgrep \
    openssh-server \
    python3-venv \
    libfuse2

echo "--- Configuring SSH ---"
sudo systemctl enable --now ssh
sudo ufw allow ssh || true

echo "--- Installing Programming Languages ---"
sudo apt install -y python3-pip python3-venv python3-dev

# Go (using the longsleep PPA for the most stable/recent version)
sudo add-apt-repository ppa:longsleep/golang-backports -y
sudo apt update
sudo apt install -y golang-go

echo "--- Setting up ArduPilot Environment ---"
PROJECTS_DIR="${TARGET_HOME}/projects"
if [ ! -d "$PROJECTS_DIR/ardupilot" ]; then
    echo "Cloning ArduPilot into $PROJECTS_DIR..."
    git clone --recursive https://github.com/ArduPilot/ardupilot.git "$PROJECTS_DIR/ardupilot"
    
    # Configure fork remote if specified
    if [ -n "${ARDUPILOT_FORK_URL}" ]; then
        echo "Configuring fork remote for ArduPilot..."
        cd "$PROJECTS_DIR/ardupilot"
        git remote add fork "${ARDUPILOT_FORK_URL}"
        cd - > /dev/null
    fi
    
    echo "Running ArduPilot prerequisite script..."
    # Note: We CD into the directory because some scripts expect relative paths
    cd "$PROJECTS_DIR/ardupilot"
    bash Tools/environment_install/install-prereqs-ubuntu.sh -y
    cd - > /dev/null
fi

echo "--- Installing arduino-cli & Teensy Rules ---"
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
sudo mv ./bin/arduino-cli /usr/local/bin/
rm -rf ./bin

wget https://www.pjrc.com/teensy/00-teensy.rules
sudo mv 00-teensy.rules /etc/udev/rules.d/

sudo udevadm control --reload-rules
sudo udevadm trigger

# Add user to the dialout group (needed for USB serial devices)
sudo usermod -a -G dialout "${TARGET_USER}"

# Download latest Arduino IDE AppImage
mkdir -p "${TARGET_HOME}/Desktop"
cd "${TARGET_HOME}/Desktop"
if [ ! -f arduino-ide_latest_Linux_64bit.AppImage ]; then
    echo "Downloading Arduino IDE AppImage..."
    wget https://downloads.arduino.cc/arduino-ide/arduino-ide_latest_Linux_64bit.AppImage
    chmod +x arduino-ide_latest_Linux_64bit.AppImage
fi
cd - > /dev/null

# Configure arduino-cli
arduino-cli config init || true
arduino-cli config set directories.user "${TARGET_HOME}/Arduino"
arduino-cli config set directories.data "${TARGET_HOME}/.arduino15"
arduino-cli config add board_manager.additional_urls https://www.pjrc.com/teensy/package_teensy_index.json
arduino-cli core update-index
arduino-cli core install teensy:avr

arduino-cli lib install "Adafruit GFX Library" || true
arduino-cli lib install "Adafruit NeoPixel" || true
arduino-cli lib install "Adafruit NeoMatrix" || true

echo "--- Setting up git-prompt.sh ---"
curl -fsSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh -o "${TARGET_HOME}/.git-prompt.sh"

echo "--- Copying Dotfiles to ${TARGET_HOME} ---"
for file in .vimrc .screenrc .bashrc; do
    if [ -f "${TARGET_HOME}/${file}" ] && [ ! -L "${TARGET_HOME}/${file}" ]; then
        echo "Backing up existing ${TARGET_HOME}/${file} to ${file}.bak"
        cp "${TARGET_HOME}/${file}" "${TARGET_HOME}/${file}.bak"
    fi
    echo "Copying ${file} to ${TARGET_HOME}/${file}"
    cp "${SCRIPT_DIR}/${file}" "${TARGET_HOME}/${file}"
    chown "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/${file}" || true
done

echo "--- Installing AI Assistant CLI Tools ---"
# Install Antigravity CLI (agy)
if ! command -v agy &> /dev/null; then
    echo "Installing Antigravity CLI..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash
else
    echo "Antigravity CLI (agy) is already installed."
fi

# Install Claude Code (claude)
if ! command -v claude &> /dev/null; then
    echo "Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    echo "Claude Code (claude) is already installed."
fi

echo "--- Running Sub-Scripts ---"
# 1. Run vim installer
bash "${SCRIPT_DIR}/install_vim.sh"

# 2. Run git config setup
bash "${SCRIPT_DIR}/setup_git.sh"

# 3. Join ZeroTier network
bash "${SCRIPT_DIR}/zerotier.sh"

# Clean up apt packages
sudo apt autoremove -y

echo "========================================================================"
echo "🎉 Machine Bootstrap Orchestration Complete!"
echo "NOTE: Please log out and log back in to apply group membership changes."
echo "========================================================================"
