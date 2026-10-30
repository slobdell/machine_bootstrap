# Machine Bootstrap & Dotfiles

This repository contains personal machine-bootstrapping scripts and dotfiles to configure a fresh Ubuntu development machine with standard tools, editor setups, and identities.

---

## 🛠️ Included Tools & Environment
- **Editor**: Vim with custom `.vimrc` (built-ins only, persistent undo, and auto-gofmt).
- **Terminal Multiplexer**: Screen with custom status line `.screenrc`.
- **Shell**: Bash configuration `.bashrc` featuring:
  - Custom colored Git status and branch prompt (via `git-prompt.sh`).
  - ArduPilot completion rules and Gazebo simulation paths.
- **Skins & Utilities**: Google Chrome, CMake, Git LFS, htop, ripgrep, tree, ffmpeg, net-tools, etc.
- **Identity & Networking**: Git credentials setup, SSH key registration, and ZeroTier LAN connection (featuring automated MTU clamping and IPv6 transport blacklist fixes for stability).
- **Development Ecosystems**: Python, Go, and Arduino toolchain (`arduino-cli` + Teensy 4.x support + Arduino IDE AppImage).

---

## 🚀 Getting Started

If you are setting up dual-boot Windows & Ubuntu on a laptop, please follow the [Dual-Boot Windows & Ubuntu Setup Guide](file:///home/slobdell/Desktop/MAKE_THIS_A_GIT_REPO/DUAL_BOOT_GUIDE.md) first to prepare Windows, flash the bootable USB, configure BIOS/UEFI settings, and perform the installation.

Once Ubuntu is installed, proceed with the following steps.

### Step 0 (Optional): Enable Remote Access
A fresh Ubuntu Desktop install has no SSH server. To drive the rest of the setup remotely, run this once at the machine's own keyboard:
```bash
sudo apt update && sudo apt install -y openssh-server && sudo systemctl enable --now ssh
```
Then, from your existing machine, run `ssh-copy-id <user>@<new-machine-ip>` in a regular terminal (it prompts for the password, so it can't be run non-interactively).

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
9. Set up the Android SDK, Docker Engine, and (if an NVIDIA GPU is present) the NVIDIA driver, CUDA toolkit, and NVIDIA Container Toolkit. See [NVIDIA GPU Machines](#-nvidia-gpu-machines).
10. If the GPU is working, set up the GPU research environment (Miniforge, PyTorch, JupyterLab). See [GPU Research Environment](#-gpu-research-environment).

The script is safe to re-run. If it reports that a reboot is required (new kernel or NVIDIA driver), reboot and run it again to verify.

*Note: You should log out and log back in for all changes (such as the `dialout` group membership) to take effect.*

---

## ⚙️ Post-Bootstrap Steps

After the `bootstrap_machine.sh` script completes, you need to perform the following two manual steps to finalize network access and git authentication:

### 1. Authorize ZeroTier VPN Access
Because the ZeroTier network is private, your new machine must be authorized by the network administrator to obtain an IP address and connect:
1. On the new laptop, get your 10-digit **ZeroTier Node ID** (Address):
   ```bash
   sudo zerotier-cli info
   ```
2. Log into the **ZeroTier Central Console** ([my.zerotier.com](https://my.zerotier.com)) and select network `f3797ba7a8546f34`.
3. Scroll down to the **Members** section, locate your new Node ID, and check the **Auth** checkbox to authorize it.
4. Verify that the laptop receives its network IP address:
   ```bash
   sudo zerotier-cli listnetworks
   ```
5. *Note: After authorization, there can be a propagation and UDP hole-punching delay of 1–2 minutes before the machines can actively ping or SSH each other.*

### 2. ZeroTier Network Stability & Latency Optimization (Automated)
To prevent SSH sessions from hanging and to optimize local latency, the bootstrap scripts automatically configure:
- **MTU Clamping**: Enforces an MTU limit of `1300` on virtual ZeroTier interfaces using a NetworkManager dispatcher hook (`/etc/NetworkManager/dispatcher.d/99-zerotier-mtu.sh`). This avoids MTU Black Hole fragmentation issues (where the physical MTU is 1500 but ZeroTier defaults to 2800, leading to packet drops).
- **IPv4 Transport Priority**: Disables physical IPv6 peer discovery by blacklisting `::/0` in `/var/lib/zerotier-one/local.conf`. This forces ZeroTier to discover local peers exclusively via IPv4 transport, lowering baseline latency to sub-5ms expectations by bypassing poor local router multicast IPv6 optimization.

### 3. Configure GitHub Authentication (Optional but Recommended)
If you want to execute git operations (push/pull/fetch) directly on this laptop without forwarding your SSH agent:
1. Authenticate with GitHub using the CLI:
   ```bash
   gh auth login
   ```
2. Choose **SSH** as your preferred protocol and allow the tool to upload your newly generated public key (`~/.ssh/id_ed25519.pub`) directly to your GitHub profile.

---

## 🎮 NVIDIA GPU Machines
`setup_gpu.sh` (run automatically by the bootstrap; exits immediately if there is no NVIDIA GPU):
- Installs the NVIDIA driver with the **open kernel modules** (`nvidia-driver-<branch>-open`) via `ubuntu-drivers`. RTX 50xx (Blackwell) and newer cards *only* work with the open modules. The Ubuntu installer's "third-party drivers" checkbox installs the proprietary flavor, which fails with `requires use of the NVIDIA open kernel modules` in `journalctl -k`: no display output from the card, and `nvidia-smi` reports "No devices were found". The script purges any other driver branch/flavor first.
- Uses Canonical's **precompiled, signed** modules, so it works with **Secure Boot on** (no MOK enrollment, no DKMS) and tracks kernel upgrades.
- Installs the CUDA toolkit from NVIDIA's repo (`nvcc` on `PATH` via `/etc/profile.d/cuda.sh`). An apt pin stops that repo from ever replacing the Ubuntu driver packages.
- Enables `nvidia-persistenced` and, if Docker is installed, the NVIDIA Container Toolkit (`docker run --gpus all ...`).
- Pin versions with `NVIDIA_DRIVER_BRANCH` / `CUDA_TOOLKIT_PACKAGE` in `config.env`.

Verify after a reboot:
```bash
nvidia-smi
nvcc --version
docker run --rm --gpus all ubuntu nvidia-smi
```
*Tip:* On CPUs with integrated graphics, plugging the monitor into the motherboard leaves all GPU VRAM free for compute; plugging it into the card also works once the driver is installed.

### 🔬 GPU Research Environment
`setup_research.sh` (run automatically by the bootstrap once `nvidia-smi` works; safe to re-run by hand):
- Installs `nvtop` and **Miniforge** (conda + mamba) in `~/miniforge3`, hooked into `~/.bashrc` without auto-activating `base`.
- Creates a shared `research` conda env: scientific Python, JupyterLab, and PyTorch from the `cu128` wheel index (the oldest CUDA build that supports RTX 50xx). PyTorch bundles its own CUDA runtime, so it only depends on the driver, not the system CUDA toolkit.
- Adds two commands to `~/.local/bin`:
  - `research-jupyter` starts JupyterLab in a detached `screen` session named `jupyter`, bound to localhost only. From a laptop: `ssh -L 8888:localhost:8888 <host>`, then open the printed URL.
  - `research-gpu-check` confirms PyTorch can compute on the GPU and prints a bf16 TFLOPS number.
- Override `RESEARCH_ENV` / `TORCH_INDEX_URL` / `JUPYTER_PORT` in `config.env`. Project-specific tools belong in each project's own env, not here.

---

## 🍎 macOS (Non-Developer Machines)
`setup_mac.sh` sets up a fresh Mac for someone else without logging into any of your accounts. It only uses tools that ship with macOS (no Homebrew/Xcode needed) and:
- Installs the **Claude desktop app** to `/Applications` (falls back to Claude's auto-update feed, since the claude.ai DMG link blocks `curl`).
- Installs the **Claude Code CLI** (`claude`) and adds `~/.local/bin` to `PATH` in `~/.zshrc`.
- Installs **ZeroTier**, applies the same IPv6 transport blacklist as Linux (in `/Library/Application Support/ZeroTier/One/local.conf`), joins the network, and prints the Node ID. MTU clamping is not applied (the dispatcher hook is Linux-only).

To get the script onto the Mac without logging in to GitHub, serve just that file from a Linux machine on the same LAN (don't serve the repo directory, since `config.env` is in it):
```bash
mkdir -p /tmp/serve && cp setup_mac.sh /tmp/serve/ && cd /tmp/serve && python3 -m http.server 8000
```
Then, in Terminal on the Mac:
```bash
curl -fsSLO http://<linux-lan-ip>:8000/setup_mac.sh && bash setup_mac.sh
```
Afterwards:
1. Authorize the printed Node ID in ZeroTier Central (see above).
2. Open a new Terminal and run `claude` (or open Claude.app); the user signs in with their own account.
3. *Optional:* enable SSH via **System Settings → General → Sharing → Remote Login** (off by default on macOS), or `sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist`.
4. The first `git` invocation will prompt to install the Xcode Command Line Tools; accept it.

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

*Note: For agent forwarding to function correctly when connecting to GitHub, ensure that the remote server's `~/.ssh/config` file does not restrict key usage (i.e., configure `IdentitiesOnly no` instead of `yes` for `Host github.com` so the client can query your forwarded agent).*
