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

# Apply git identity configurations
git config --global user.name "${GIT_NAME:?Please set GIT_NAME in config.env}"
git config --global user.email "${GIT_EMAIL:?Please set GIT_EMAIL in config.env}"
git config --global init.defaultBranch main

# Generate SSH key if it doesn't exist
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -C "${GIT_EMAIL}" -f "$HOME/.ssh/id_ed25519" -N ""
else
    echo "SSH key already exists at $HOME/.ssh/id_ed25519, skipping generation."
fi

# Add key to ssh-agent
if [ -z "$SSH_AUTH_SOCK" ]; then
    echo "No SSH agent detected, starting one..."
    eval "$(ssh-agent -s)"
fi
ssh-add "$HOME/.ssh/id_ed25519"

# Configure ssh client config for GitHub
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/config" ] || ! grep -q "Host github.com" "$HOME/.ssh/config"; then
    echo "Configuring SSH config to automatically use this key for GitHub..."
    cat <<EOF >> "$HOME/.ssh/config"

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly no
EOF
    chmod 600 "$HOME/.ssh/config"
fi

echo "======================================================================"
echo "GitHub SSH Key Setup"
echo "======================================================================"
echo "OPTION A (Automated via GitHub CLI):"
echo "  1. Run: gh auth login"
echo "  2. Follow the prompts. It can automatically configure SSH and upload"
echo "     a public key directly to your account!"
echo "  - OR - if you are already authenticated but want to upload this generated key:"
echo "    gh ssh-key add \"\$HOME/.ssh/id_ed25519.pub\" --title \"\$(hostname)\""
echo ""
echo "OPTION B (Manual copy-paste):"
echo "  1. Go to GitHub > Settings > SSH and GPG keys > New SSH Key."
echo "  2. Copy and paste the key below, naming it '$(hostname)':"
echo "======================================================================"
cat "$HOME/.ssh/id_ed25519.pub"
echo "======================================================================"
echo "Once added, you can test it with: ssh -T git@github.com"

# Optionally clone extra repositories if configured
if [ -n "${EXTRA_REPOS_TO_CLONE}" ]; then
    mkdir -p "$HOME/projects"
    cd "$HOME/projects"
    
    for repo in ${EXTRA_REPOS_TO_CLONE}; do
        REPO_NAME=$(basename "${repo}" .git)
        if [ ! -d "${REPO_NAME}" ]; then
            echo "Cloning configured repository into $HOME/projects/${REPO_NAME}..."
            git clone "${repo}" || echo "Warning: Failed to clone ${repo}. You may need to authenticate first."
        else
            echo "Repository ${REPO_NAME} already exists in $HOME/projects, skipping clone."
        fi
    done
fi
