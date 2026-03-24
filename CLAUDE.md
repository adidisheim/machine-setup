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

## Step 3b: Telegram Channel Plugin

**Skip check:** Check ALL of the following. If all pass, skip entirely:
1. `~/.claude/channels/telegram/.env` exists with `TELEGRAM_BOT_TOKEN`
2. `claude plugin list` shows telegram as enabled
3. `which bun` succeeds
4. `claude --version` shows >= 2.1.76

**Only if not already configured — ASK the user**: "Do you want to set up Telegram notifications for Claude? This lets you two-way chat with Claude from your phone while it runs on the VM."

If no, skip entirely.

If yes, follow these steps **in order**:

### 1. Ensure Claude Code >= 2.1.76

**CRITICAL:** The `--channels` flag (required for two-way Telegram) and proper marketplace parsing only exist in Claude Code >= 2.1.76. Older versions will fail silently or error with "unknown option --channels".

```bash
claude --version
# If < 2.1.76:
sudo npm install -g @anthropic-ai/claude-code@latest
```

**Version gotcha:** `claude install stable` (native installer) may install an older version than npm. If multiple binaries exist, the wrong one may shadow the new one. After upgrading, verify you're running the right binary:

```bash
which -a claude   # Shows all binaries in PATH order
claude --version  # Must be >= 2.1.76
```

If the wrong version is first in PATH, remove stale binaries:
```bash
# Common stale locations (check versions before removing):
~/.local/bin/claude      # native installer (may be old)
/usr/local/bin/claude    # old npm symlink
/usr/bin/claude          # current npm install
```

### 2. Install Bun

```bash
which bun > /dev/null 2>&1 || (curl -fsSL https://bun.sh/install | bash)
export PATH="$HOME/.bun/bin:$PATH"
bun --version
```

### 3. Add the official plugin marketplace

```bash
if [ ! -d ~/.claude/plugins/marketplaces/claude-plugins-official ]; then
    claude plugin marketplace add anthropics/claude-plugins-official
fi
claude plugin marketplace update
```

### 4. Create a Telegram bot (user action)

Tell the user:
1. Open a chat with **@BotFather** on Telegram
2. Send `/newbot`
3. Choose a name and username (must end in `bot`)
4. **Copy the token** (looks like `123456789:AAHfiqksKZ8...`)
5. Paste it here

### 5. Register the plugin (manual method — `claude plugin install` is broken)

**WARNING:** `claude plugin install telegram@claude-plugins-official` fails with "Plugin not found" on many versions due to a marketplace schema validation bug (`git-subdir` source type not recognized). **Do NOT waste time retrying it.** Instead, register manually:

**a) Create the plugin cache:**
```bash
export PATH="$HOME/.bun/bin:$PATH"
SRC=~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram
DEST=~/.claude/plugins/cache/claude-plugins-official/telegram/0.0.1
mkdir -p "$DEST"
cp -r "$SRC"/.claude-plugin "$SRC"/server.ts "$SRC"/package.json "$SRC"/bun.lock \
      "$SRC"/.mcp.json "$SRC"/.npmrc "$SRC"/LICENSE "$SRC"/README.md \
      "$SRC"/ACCESS.md "$SRC"/skills "$DEST/"
cd "$DEST" && bun install
```

**b) Create `~/.claude/plugins/installed_plugins.json`:**
```json
{
  "version": 2,
  "plugins": {
    "telegram@claude-plugins-official": [{
      "scope": "user",
      "installPath": "~/.claude/plugins/cache/claude-plugins-official/telegram/0.0.1",
      "version": "0.0.1"
    }]
  }
}
```

**c) Add to `~/.claude/settings.json`** (merge, don't overwrite):
```json
{
  "enabledPlugins": {
    "telegram@claude-plugins-official": true
  }
}
```

**d) Verify:**
```bash
claude plugin list
# Should show: telegram@claude-plugins-official — Version: 0.0.1 — Status: ✔ enabled
```

### 6. Save the bot token

```bash
mkdir -p ~/.claude/channels/telegram
echo "TELEGRAM_BOT_TOKEN=<PASTE_TOKEN_HERE>" > ~/.claude/channels/telegram/.env
chmod 600 ~/.claude/channels/telegram/.env
```

### 7. Launch and pair

Launch with the `claude-telegram-new` script (set up in Step 4 below), then:

1. DM your bot on Telegram — it replies with a 6-character pairing code
2. In the Claude tmux session, run: `/telegram:access pair <code>`
3. Lock down access: `/telegram:access policy allowlist`

The session runs in tmux — you can safely close the terminal and reconnect later with `tmux attach -t claude-tg-0`.

### 8. Get your user ID (optional)

Message **@userinfobot** on Telegram to get your numeric user ID for access control.

### Troubleshooting

- **"unknown option --channels":** Claude Code is too old. Must be >= 2.1.76. Run `sudo npm install -g @anthropic-ai/claude-code@latest`.
- **One-way only (Claude sends but doesn't receive):** You're using `--plugin-dir` instead of `--channels`. The `--channels` flag is what enables two-way communication. Requires the plugin to be formally registered (Step 5 above).
- **`claude plugin install` "not found":** Known bug — marketplace schema validation fails on `git-subdir` entries and rejects ALL plugins. Use the manual registration in Step 5 instead.
- **Bot doesn't respond to DMs:** Check that Bun is in PATH inside tmux. The launch script must `export PATH="$HOME/.bun/bin:$PATH"` before calling claude.
- **"TELEGRAM_BOT_TOKEN required":** Verify `~/.claude/channels/telegram/.env` exists with the correct token (no quotes around value).
- **Multiple claude binaries:** Run `which -a claude` — the first hit wins. Remove stale old versions that shadow the npm install.

---

## Step 4: Claude Launch Scripts

**Skip check:** Check if `claude-local.sh`, `claude-overnight-new.sh`, `claude-overnight-attach.sh`, `claude-overnight-kill-all.sh`, and `claude-telegram-new.sh` already exist in the user's working directory AND `~/bin/claude-local` symlinks exist. If so, skip.

**Only if not already configured — ASK the user**: "What is the path to your main working/code directory on this machine?"

Then copy from this repo:
```bash
cp ~/machine-setup/tmux/claude-local.sh <WORKING_DIR>/
cp ~/machine-setup/tmux/claude-overnight-new.sh <WORKING_DIR>/
cp ~/machine-setup/tmux/claude-overnight-attach.sh <WORKING_DIR>/
cp ~/machine-setup/tmux/claude-overnight-kill-all.sh <WORKING_DIR>/
cp ~/machine-setup/tmux/claude-telegram-new.sh <WORKING_DIR>/
chmod +x <WORKING_DIR>/claude-*.sh
```

Also add them to PATH for convenience:
```bash
mkdir -p ~/bin
ln -sf <WORKING_DIR>/claude-local.sh ~/bin/claude-local
ln -sf <WORKING_DIR>/claude-overnight-new.sh ~/bin/claude-overnight-new
ln -sf <WORKING_DIR>/claude-overnight-attach.sh ~/bin/claude-overnight-attach
ln -sf <WORKING_DIR>/claude-overnight-kill-all.sh ~/bin/claude-overnight-kill-all
ln -sf <WORKING_DIR>/claude-telegram-new.sh ~/bin/claude-telegram-new
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
1. Generate SSH key:
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "antoine.didisheim@unimelb.edu.au" -f ~/.ssh/spartan_key -N ""
```

2. Configure SSH config (before copying the key, so ssh-copy-id can use it):
```bash
grep -q "Host spartan" ~/.ssh/config 2>/dev/null || cat >> ~/.ssh/config << 'EOF'
Host spartan
    HostName spartan.hpc.unimelb.edu.au
    User adidishe
    IdentityFile ~/.ssh/spartan_key
    StrictHostKeyChecking no
EOF
```

3. **Fix permissions** — `ssh-copy-id` will fail if `~/.ssh/config` is group/world-readable:
```bash
chmod 600 ~/.ssh/config
chmod 700 ~/.ssh
```

4. Copy the key to Spartan using `ssh-copy-id` (the user will enter their Spartan password once):
```bash
ssh-copy-id -i ~/.ssh/spartan_key.pub adidishe@spartan.hpc.unimelb.edu.au
```
Tell the user: **"Enter your Spartan password when prompted. This is the only time you'll need it."**

5. Test passwordless access:
```bash
ssh -o BatchMode=yes -o ConnectTimeout=10 spartan "hostname"
```

**Troubleshooting:** If `ssh-copy-id` fails with "Bad owner or permissions", re-run `chmod 600 ~/.ssh/config && chmod 700 ~/.ssh` and retry. Do NOT fall back to manually echoing keys into `authorized_keys` — `ssh-copy-id` handles idempotency and formatting correctly.

**Deploy Spartan job monitor script:**
```bash
cp ~/machine-setup/scripts/spartan-wait.sh ~/bin/spartan-wait
chmod +x ~/bin/spartan-wait
```
This script is used by Claude to automatically track `sbatch` jobs in the background. After any `sbatch` submission, Claude launches `spartan-wait <JOBID> [output_pattern]` with `run_in_background: true` and gets notified when the job finishes.

**Spartan CLAUDE.md template:** Remind the user that `~/machine-setup/templates/spartan_claude_md.md` contains a full Spartan operations guide (with critical safety rules, including the mandatory job monitoring protocol) that should be included in any project CLAUDE.md that uses Spartan. Print its path.

---

## Step 6: Final Verification

Only check/report — never re-run steps here. Run each check and report pass/fail:

- [ ] **Dropbox**: `pgrep -x dropbox > /dev/null && echo PASS || echo SKIP/FAIL`
- [ ] **GitHub auth**: `gh auth status 2>&1 | grep -q "Logged in" && echo PASS || echo FAIL`
- [ ] **Git identity**: `git config --global user.name` is non-empty
- [ ] **Email MCP**: `grep -q '"email"' ~/.claude/settings.json 2>/dev/null && echo PASS || echo SKIP`
- [ ] **Telegram plugin**: `[ -f ~/.claude/channels/telegram/.env ] && which bun > /dev/null 2>&1 && echo PASS || echo SKIP`
- [ ] **Launch scripts**: `ls ~/bin/claude-local ~/bin/claude-telegram-new > /dev/null 2>&1 && echo PASS || echo FAIL`
- [ ] **Spartan SSH**: `ssh -o BatchMode=yes -o ConnectTimeout=5 spartan "hostname" 2>/dev/null && echo PASS || echo SKIP`

Print a summary table with status for each component. Only flag items as FAIL if they were attempted and didn't work. Items the user declined should show SKIP.

---

## Notes

- GitHub user: `adidisheim`
- Email: `antoine.didisheim@unimelb.edu.au`
- Spartan user: `adidishe`
- Spartan host: `spartan.hpc.unimelb.edu.au`
- Email MCP repo: `https://github.com/adidisheim/claude-email-mcp.git`

## Research Project Best Practices

### Experiment Archiving

For any research project, set up an `experiments/` folder to track all computational experiments. This creates an auditable history of what was tried, why, and what was learned.

**Setup:**
```bash
mkdir -p experiments
cp ~/machine-setup/templates/experiment_index.md experiments/INDEX.md
cp ~/machine-setup/templates/experiment_template.md experiments/TEMPLATE.md
```

**Rule for CLAUDE.md:** Add this to any research project's CLAUDE.md:
```
After completing any experiment batch (training + eval), create an experiment archive:
1. Create experiments/YYYY-MM-DD_short_name/ with code/, slurm/, README.md, results.json
2. Update experiments/INDEX.md with one-line summary
Keep archives lightweight: code + markdown + JSON only. No data or model weights.
```

Templates are in `~/machine-setup/templates/experiment_template.md` and `experiment_index.md`.

### Telegram Communication Rules

When Telegram is set up (Step 3b), add these rules to the global `~/.claude/CLAUDE.md`:

```
## Telegram Communication Rules

When Telegram is connected:
1. **Forward all blocking questions to Telegram.** If you ask the user a question in the
   terminal that blocks progress (multiple choice, confirmation, etc.), you MUST also send
   it via Telegram. The user is often away from the laptop.
2. **Always respond to Telegram messages.** Never silently ignore an incoming Telegram
   message, even if you are mid-task or waiting for terminal input.
```

**Why:** The user monitors long-running sessions from their phone. If Claude asks a question only in the terminal and the user isn't at the laptop, the session appears dead/stuck. This has caused lost hours in practice.
