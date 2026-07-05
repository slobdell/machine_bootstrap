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
eval "$(ssh-agent -s)"
ssh-add "$HOME/.ssh/id_ed25519"

echo "======================================================================"
echo "You need to copy your public key to your GitHub account settings."
echo "Go to GitHub > Settings > SSH and GPG keys > New SSH Key."
echo "Paste the following key and give it a name like '$(hostname)':"
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
            git clone "${repo}"
        else
            echo "Repository ${REPO_NAME} already exists in $HOME/projects, skipping clone."
        fi
    done
fi
