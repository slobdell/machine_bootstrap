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

To bootstrap a fresh Ubuntu installation (such as a headless server):

### Step 0: Ensure SSH Access (For Headless Servers)
Before running this script from your local machine, copy your local public SSH key to the fresh server to allow passwordless access:
```bash
ssh-copy-id username@new-server-ip
```

### Step 1: Clone the Repository
Log into the server over SSH, then clone this repository:
```bash
git clone <your-repo-ssh-url> ~/machine-bootstrap
cd ~/machine-bootstrap
```

### Step 2: Configure Environment Variables
Copy the template configuration file to `config.env` and populate your settings:
```bash
cp config.env.example config.env
vim config.env
```
Ensure you fill in:
- Your Git identity (`GIT_NAME`, `GIT_EMAIL`).
- Any ArduPilot/extra repos you want cloned automatically.
- `INSTALL_GUI_IDE="false"` if this is a headless server (prevents downloading the graphical Arduino IDE AppImage).

### Step 3: Run the Master Bootstrap Script
Execute the main master orchestration script:
```bash
./bootstrap_machine.sh
```
This script will:
1. Update system packages and install standard dev tools.
2. Setup the ArduPilot environment & programming languages (Go, Python).
3. Setup the Arduino CLI and Teensy rules.
4. Download the Arduino IDE AppImage (only if `INSTALL_GUI_IDE="true"`).
5. Download `git-prompt.sh` for prompt customization.
6. Back up existing user configurations (`~/.bashrc`, `~/.vimrc`, `~/.screenrc`) and link the new versions.
7. Install vim-nox, set default editors, and finalize file ownerships.
8. Generate SSH keys, map them to `github.com` in `~/.ssh/config`, and output the public key to add to GitHub.
9. Install and configure ZeroTier.

*Note: You should log out and log back in for all changes (such as the `dialout` group membership) to take effect.*
