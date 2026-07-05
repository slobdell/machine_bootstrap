# Machine Bootstrap & Dotfiles

This repository contains personal machine-bootstrapping scripts and dotfiles to configure a fresh Ubuntu development machine with standard tools, editor setups, and identities.

---

## 🛠️ Included Tools & Environment
- **Editor**: Vim with custom `.vimrc` (built-ins only, persistent undo, and auto-gofmt).
- **Terminal Multiplexer**: Screen with custom status line `.screenrc`.
- **Shell**: Bash configuration `.bashrc` featuring:
  - Custom colored Git status and branch prompt (via `git-prompt.sh`).
  - ArduPilot completion rules and Gazebo simulation paths.
- **Skins & Utilities**: CMake, Git LFS, htop, ripgrep, tree, ffmpeg, net-tools, etc.
- **Identity & Networking**: Git credentials setup, SSH key registration, and ZeroTier LAN connection.
- **Development Ecosystems**: Python, Go, and Arduino toolchain (`arduino-cli` + Teensy 4.x support).

---

## 🚀 Getting Started

To bootstrap a fresh Ubuntu installation:

### Step 1: Clone the Repository
Clone this repository to your local directory (e.g., `~/machine-bootstrap`):
```bash
git clone <your-repo-ssh-url> ~/machine-bootstrap
cd ~/machine-bootstrap
```

### Step 2: Configure Environment Variables
Copy the template configuration file to `config.env` and populate your personal configuration settings:
```bash
cp config.env.example config.env
vim config.env
```
Ensure you fill in your actual Git details, ZeroTier network ID, and preferred username.

### Step 3: Run the Master Bootstrap Script
Execute the main master orchestration script:
```bash
./bootstrap_machine.sh
```
This script will:
1. Update system packages and install standard dev tools.
2. Setup the ArduPilot environment & programming languages (Go, Python).
3. Setup the Arduino CLI, Teensy rules, and download the Arduino IDE AppImage.
4. Download `git-prompt.sh` for prompt customization.
5. Back up existing user configurations (`~/.bashrc`, `~/.vimrc`, `~/.screenrc`) and link the new versions.
6. Install vim-nox, set default editors, and finalize file ownerships.
7. Generate dynamic SSH keys and display the public key for GitHub linking.
8. Install and configure ZeroTier.

*Note: You should log out and log back in for all changes (such as the `dialout` group membership) to take effect.*
