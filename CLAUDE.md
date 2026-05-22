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

## Step 3: Claude Launch Scripts

**Skip check:** Check if `claude-local.sh`, `claude-overnight-new.sh`, `claude-overnight-attach.sh`, and `claude-overnight-kill-all.sh` already exist in the user's working directory AND `~/bin/claude-local` symlinks exist. If so, skip.

**Only if not already configured — ASK the user**: "What is the path to your main working/code directory on this machine?"

Then copy from this repo:
```bash
cp ~/machine-setup/tmux/claude-local.sh <WORKING_DIR>/
cp ~/machine-setup/tmux/claude-overnight-new.sh <WORKING_DIR>/
cp ~/machine-setup/tmux/claude-overnight-attach.sh <WORKING_DIR>/
cp ~/machine-setup/tmux/claude-overnight-kill-all.sh <WORKING_DIR>/
cp ~/machine-setup/tmux/claude-remote-new.sh <WORKING_DIR>/
chmod +x <WORKING_DIR>/claude-*.sh
```

Also add them to PATH for convenience:
```bash
mkdir -p ~/bin
ln -sf <WORKING_DIR>/claude-local.sh ~/bin/claude-local
ln -sf <WORKING_DIR>/claude-overnight-new.sh ~/bin/claude-overnight-new
ln -sf <WORKING_DIR>/claude-overnight-attach.sh ~/bin/claude-overnight-attach
ln -sf <WORKING_DIR>/claude-overnight-kill-all.sh ~/bin/claude-overnight-kill-all
ln -sf <WORKING_DIR>/claude-remote-new.sh ~/bin/claude-remote-new
# Only add to .bashrc if not already there
grep -q 'HOME/bin' ~/.bashrc || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
```

The main launcher is `claude-overnight-new`: it starts a persistent tmux session running Claude with the latest 1M-context Opus model and `/effort max` and `/compact auto` enabled.

---

## Step 4: Spartan HPC Setup (if applicable)

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

## Step 5: Final Verification

Only check/report — never re-run steps here. Run each check and report pass/fail:

- [ ] **Dropbox**: `pgrep -x dropbox > /dev/null && echo PASS || echo SKIP/FAIL`
- [ ] **GitHub auth**: `gh auth status 2>&1 | grep -q "Logged in" && echo PASS || echo FAIL`
- [ ] **Git identity**: `git config --global user.name` is non-empty
- [ ] **Launch scripts**: `ls ~/bin/claude-local ~/bin/claude-overnight-new > /dev/null 2>&1 && echo PASS || echo FAIL`
- [ ] **Spartan SSH**: `ssh -o BatchMode=yes -o ConnectTimeout=5 spartan "hostname" 2>/dev/null && echo PASS || echo SKIP`

Print a summary table with status for each component. Only flag items as FAIL if they were attempted and didn't work. Items the user declined should show SKIP.

---

## Notes

- GitHub user: `adidisheim`
- Email: `antoine.didisheim@unimelb.edu.au`
- Spartan user: `adidishe`
- Spartan host: `spartan.hpc.unimelb.edu.au`

## Subagent Model Preference

**Default to the latest Opus model for every subagent (Agent tool call). Never Sonnet, never Haiku.**

When spawning subagents via the `Agent` tool, always pass `model: "opus"` unless the user has explicitly asked for a different model in the same request. The user prioritizes output quality over token cost, so cheaper models are not an acceptable default. The `opus` alias resolves to whatever the latest Opus generation is at the time of execution.

If a project's own CLAUDE.md overrides this with a project-specific subagent model, follow that — but this is the default for any new project.

## Research Project Best Practices

### Experiment Archives

For research projects, set up experiment archives so each completed experiment gets a frozen snapshot:

```bash
mkdir -p experiments
cp ~/machine-setup/templates/experiment_index.md experiments/INDEX.md
cp ~/machine-setup/templates/experiment_template.md experiments/TEMPLATE.md
```

Each experiment goes in `experiments/YYYY-MM-DD_<name>/` with code, scripts, `results.json`, and a README. Update `experiments/INDEX.md` to list completed experiments.

Templates: `~/machine-setup/templates/experiment_*.md`.

> Cross-session state tracking (experiments-in-progress, insights, goals, working-context) is handled by Claude Code's built-in memory system at `~/.claude/projects/<project>/memory/MEMORY.md`. See the global `~/.claude/CLAUDE.md` for the auto-memory rules.
