# Machine Setup — CLAUDE.md

This repo bootstraps a new VM for development. When the user says **"set me up"**, follow every step below in order. Ask questions where indicated.

## CRITICAL RULE: Idempotency

**Before executing ANY step, check if it's already done. If it is, print "Step N: [name] — already configured, skipping." and move on.** Never re-install, re-configure, or re-ask for something that's already working. The detection checks for each step are listed below.

## Prerequisites

This script assumes:
- Ubuntu (AWS/GCP VM)
- Claude Code is already installed
- Internet access

---

## Step 1: Dropbox

**Skip check:** Run `pgrep -x dropbox` or check if `~/.dropbox-dist/dropboxd` exists AND `~/Dropbox` directory exists with contents. If both true, skip this step entirely.

Install Dropbox CLI and configure selective sync.

```bash
# Install Dropbox daemon
cd ~ && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -

# Start daemon (will print a URL for linking — show it to the user)
~/.dropbox-dist/dropboxd &
```

**IMPORTANT — Interactive step:**
1. The daemon prints a URL. Tell the user to open it in a browser and link their account.
2. Wait for sync to start (a `~/Dropbox` folder appears).
3. **ASK the user**: "Which folder(s) inside Dropbox do you want to keep synced? Everything else will be excluded."
4. Install the Dropbox CLI helper and exclude everything except the chosen folder(s):

```bash
# Install Dropbox CLI
mkdir -p ~/bin
wget -O ~/bin/dropbox.py "https://www.dropbox.com/download?dl=packages/dropbox.py"
chmod +x ~/bin/dropbox.py

# Wait for initial folder listing
sleep 10

# Exclude everything except the chosen folder
# For each top-level dir in ~/Dropbox that is NOT the chosen one:
for dir in ~/Dropbox/*/; do
    dirname=$(basename "$dir")
    if [ "$dirname" != "CHOSEN_FOLDER" ]; then
        ~/bin/dropbox.py exclude add "$dir"
    fi
done
```

5. Verify: `~/bin/dropbox.py exclude list` — should show everything excluded except the chosen folder.
6. Set Dropbox to start on boot:

```bash
# Add to crontab (only if not already there)
crontab -l 2>/dev/null | grep -q dropboxd || (crontab -l 2>/dev/null; echo "@reboot ~/.dropbox-dist/dropboxd") | crontab -
```

---

## Step 2: GitHub — Passwordless HTTPS Auth

**Skip check:** Run `gh auth status 2>&1`. If it shows "Logged in to github.com", skip the auth steps. Also check `git config --global user.name` — if already set, skip identity config.

Install git if not present (`which git`), install GitHub CLI if not present (`which gh`).

```bash
# Install git if not present
which git > /dev/null 2>&1 || (sudo apt-get update && sudo apt-get install -y git)

# Install GitHub CLI if not present
if ! which gh > /dev/null 2>&1; then
    (type -p wget >/dev/null || sudo apt install wget -y) \
      && sudo mkdir -p -m 755 /etc/apt/keyrings \
      && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
      && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
      && sudo apt update \
      && sudo apt install gh -y
fi
```

**Only if `gh auth status` fails — Interactive step:**
1. Run `gh auth login` and choose:
   - GitHub.com
   - HTTPS
   - Login with a web browser
2. It will display a one-time code and a URL (https://github.com/login/device)
3. Tell the user: **"Open this URL in your browser, enter the code: XXXXXX, and authorize."**
4. Wait for confirmation, then verify: `gh auth status`

**Only if `git config --global user.name` is empty:**
```bash
git config --global user.name "Antoine Didisheim"
git config --global user.email "antoine.didisheim@unimelb.edu.au"
```

---

## Step 3: Email MCP Server

**Skip check:** Check ALL of the following. If all pass, skip entirely:
1. Directory `~/claude-email-mcp` exists with `server.py` in it
2. `~/claude-email-mcp/venv/bin/python3` exists
3. `~/claude-email-mcp/token.json` exists (OAuth completed)
4. `~/.claude/settings.json` contains `"email"` in mcpServers

If the directory exists but some later steps are missing, resume from the missing step (don't re-clone).

```bash
# Clone only if not present
if [ ! -d ~/claude-email-mcp ]; then
    cd ~ && git clone https://github.com/adidisheim/claude-email-mcp.git
fi
cd ~/claude-email-mcp
```

**Only if `credentials.json` is missing — Interactive step:**
1. Ask the user: **"Do you have the credentials.json file for the Gmail API? If yes, paste its contents or provide the path."**
2. If they don't have it, guide them:
   - Go to https://console.cloud.google.com
   - Create/select a project, enable Gmail API
   - Go to APIs & Services > Credentials
   - Create OAuth 2.0 credentials (Desktop app type)
   - Download the JSON
3. Place it as `~/claude-email-mcp/credentials.json`

**Only if venv doesn't exist:**
```bash
cd ~/claude-email-mcp
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Only if `token.json` doesn't exist:**
```bash
cd ~/claude-email-mcp
source venv/bin/activate
python3 -c "from gmail_client import GmailClient; GmailClient('credentials.json', 'token.json'); print('Auth successful!')"
```

**Only if `~/.claude/settings.json` doesn't have the email MCP configured:**
```bash
mkdir -p ~/.claude
```
Read existing `~/.claude/settings.json` (or start with `{}`), merge in:
```json
{
  "mcpServers": {
    "email": {
      "command": "<HOME>/claude-email-mcp/venv/bin/python3",
      "args": ["<HOME>/claude-email-mcp/server.py"]
    }
  }
}
```
Replace `<HOME>` with the actual `$HOME` path. Preserve any existing settings.

**Only if `config.json` has placeholder values:** Ask the user which email addresses should be in `allowed_senders`.

---

## Step 4: Tmux Helper Scripts

**Skip check:** Check if `claude-new.sh`, `claude-attach.sh`, and `claude-kill-all.sh` already exist in the user's working directory (or `~/bin/claude-new` symlinks exist and work). If so, skip.

**Only if not already configured — ASK the user**: "What is the path to your main working/code directory on this machine?"

Then copy from this repo:
```bash
cp ~/machine-setup/tmux/claude-new.sh <WORKING_DIR>/
cp ~/machine-setup/tmux/claude-attach.sh <WORKING_DIR>/
cp ~/machine-setup/tmux/claude-kill-all.sh <WORKING_DIR>/
chmod +x <WORKING_DIR>/claude-*.sh
```

Also add them to PATH for convenience:
```bash
mkdir -p ~/bin
ln -sf <WORKING_DIR>/claude-new.sh ~/bin/claude-new
ln -sf <WORKING_DIR>/claude-attach.sh ~/bin/claude-attach
ln -sf <WORKING_DIR>/claude-kill-all.sh ~/bin/claude-kill-all
# Only add to .bashrc if not already there
grep -q 'HOME/bin' ~/.bashrc || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
```

---

## Step 5: Spartan HPC Setup (if applicable)

**Skip check:** Run `ssh -o BatchMode=yes -o ConnectTimeout=5 spartan "hostname" 2>/dev/null`. If this succeeds, Spartan SSH is already configured — skip to checking the CLAUDE.md template. If `~/.ssh/config` already has a `Host spartan` entry, also skip key generation.

**Only if not already configured — ASK the user**: "Do you need Spartan HPC access configured on this machine?"

If no, skip entirely.

If yes:

**Only if `~/.ssh/config` doesn't have a spartan entry:**
1. Set up SSH key for passwordless access:
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "antoine.didisheim@unimelb.edu.au" -f ~/.ssh/spartan_key -N ""
cat ~/.ssh/spartan_key.pub
```
2. Tell the user to add this public key to Spartan (`~/.ssh/authorized_keys` on `spartan.hpc.unimelb.edu.au`)
3. Configure SSH (only if entry doesn't exist):
```bash
grep -q "Host spartan" ~/.ssh/config 2>/dev/null || cat >> ~/.ssh/config << 'EOF'
Host spartan
    HostName spartan.hpc.unimelb.edu.au
    User adidishe
    IdentityFile ~/.ssh/spartan_key
    StrictHostKeyChecking no
EOF
```
4. Test: `ssh spartan "hostname"`

**Spartan CLAUDE.md template:** Remind the user that `~/machine-setup/templates/spartan_claude_md.md` contains a full Spartan operations guide (with critical safety rules) that should be included in any project CLAUDE.md that uses Spartan. Print its path.

---

## Step 6: Final Verification

Only check/report — never re-run steps here. Run each check and report pass/fail:

- [ ] **Dropbox**: `pgrep -x dropbox > /dev/null && echo PASS || echo SKIP/FAIL`
- [ ] **GitHub auth**: `gh auth status 2>&1 | grep -q "Logged in" && echo PASS || echo FAIL`
- [ ] **Git identity**: `git config --global user.name` is non-empty
- [ ] **Email MCP**: `grep -q '"email"' ~/.claude/settings.json 2>/dev/null && echo PASS || echo SKIP`
- [ ] **Tmux scripts**: `which claude-new > /dev/null 2>&1 && echo PASS || echo FAIL`
- [ ] **Spartan SSH**: `ssh -o BatchMode=yes -o ConnectTimeout=5 spartan "hostname" 2>/dev/null && echo PASS || echo SKIP`

Print a summary table with status for each component. Only flag items as FAIL if they were attempted and didn't work. Items the user declined should show SKIP.

---

## Notes

- GitHub user: `adidisheim`
- Email: `antoine.didisheim@unimelb.edu.au`
- Spartan user: `adidishe`
- Spartan host: `spartan.hpc.unimelb.edu.au`
- Email MCP repo: `https://github.com/adidisheim/claude-email-mcp.git`
