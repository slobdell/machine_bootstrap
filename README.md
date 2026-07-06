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
- **Development Ecosystems**: Python, Go, and Arduino toolchain (`arduino-cli` + Teensy 4.x support + Arduino IDE AppImage).

---

## 🚀 Getting Started

If you are setting up dual-boot Windows & Ubuntu on a laptop, please follow the [Dual-Boot Windows & Ubuntu Setup Guide](file:///home/slobdell/Desktop/MAKE_THIS_A_GIT_REPO/DUAL_BOOT_GUIDE.md) first to prepare Windows, flash the bootable USB, configure BIOS/UEFI settings, and perform the installation.

Once Ubuntu is installed, proceed with the following steps.

### Step 1: Clone the Repository
On your fresh Ubuntu installation, open a terminal (`Ctrl + Alt + T`). First, install `git` so that you can clone this repository:
```bash
sudo apt update && sudo apt install -y git
```

Next, clone the repository. If you choose to make this repository **public** (recommended, as all secrets and keys are ignored via `.gitignore`), you can clone it directly without any pre-existing authentication:
```bash
git clone https://github.com/slobdell/machine_bootstrap.git ~/machine-bootstrap
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
- Your ArduPilot fork URL (if applicable).
- Any extra repositories you want cloned automatically (like `plane_maker.git`).

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
7. Generate SSH keys, map them to `github.com` in `~/.ssh/config`, and output the public key to add to GitHub.
8. Install and configure ZeroTier.

*Note: You should log out and log back in for all changes (such as the `dialout` group membership) to take effect.*

---

## 🔑 SSH Agent Forwarding (Pro-Tip for Headless Servers)
Instead of generating a new SSH key on every server and copying it to GitHub, you can use **SSH Agent Forwarding**. This lets the remote server securely authenticate with GitHub using the SSH keys already present on your local machine.

### How to use it:
1. **Add keys local agent**: On your local computer, make sure your SSH key is added to your local SSH agent:
   ```bash
   ssh-add ~/.ssh/id_ed25519
   ```
2. **Connect with agent forwarding**: Log into your remote server using the `-A` flag:
   ```bash
   ssh -A username@new-server-ip
   ```
3. **Automate in ssh config**: Alternatively, you can configure your local `~/.ssh/config` file to always enable agent forwarding when connecting to this server:
   ```
   Host your-server-alias
       HostName new-server-ip
       User username
       ForwardAgent yes
   ```
Once connected, commands like `git clone` or `git pull` on the remote server will transparently utilize your local SSH key!
