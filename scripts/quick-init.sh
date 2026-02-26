#!/bin/bash
# Quick bootstrap: install essentials, then hand off to Claude
# Usage: curl the raw URL of this script | bash
#   or: bash quick-init.sh

set -e

echo "=== Machine Setup Bootstrap ==="
echo ""

# 1. Install essentials
echo "[1/4] Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq git curl wget tmux python3 python3-venv python3-pip > /dev/null 2>&1
echo "  Done."

# 2. Install GitHub CLI
echo "[2/4] Installing GitHub CLI..."
if ! command -v gh &> /dev/null; then
    (type -p wget >/dev/null || sudo apt install wget -y) \
      && sudo mkdir -p -m 755 /etc/apt/keyrings \
      && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
      && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
      && sudo apt update -qq \
      && sudo apt install gh -y -qq > /dev/null 2>&1
    echo "  Done."
else
    echo "  Already installed."
fi

# 3. GitHub auth (interactive)
echo "[3/4] GitHub authentication..."
if ! gh auth status &> /dev/null; then
    echo "  Starting GitHub device flow login..."
    gh auth login --web --git-protocol https
    git config --global user.name "Antoine Didisheim"
    git config --global user.email "antoine.didisheim@unimelb.edu.au"
    echo "  Done."
else
    echo "  Already authenticated."
fi

# 4. Clone this setup repo
echo "[4/4] Cloning machine-setup..."
if [ ! -d ~/machine-setup ]; then
    git clone https://github.com/adidisheim/machine-setup.git ~/machine-setup
    echo "  Done."
else
    echo "  Already exists, pulling latest..."
    cd ~/machine-setup && git pull && cd ~
fi

chmod +x ~/machine-setup/tmux/*.sh

echo ""
echo "=== Bootstrap complete! ==="
echo ""
echo "Next steps:"
echo "  1. Open Claude Code: claude"
echo "  2. Say: set me up"
echo "  3. Claude will read ~/machine-setup/CLAUDE.md and walk you through the rest"
echo ""
echo "Or run individual steps manually — see ~/machine-setup/CLAUDE.md"
