#!/bin/bash
# Launch a persistent Claude Code tmux session with two-way Telegram channel
# Requires: Claude Code >= 2.1.76, Bun, telegram plugin registered (see CLAUDE.md Step 3b)
n=0
while tmux has-session -t "claude-tg-$n" 2>/dev/null; do
  ((n++))
done
echo "Launching claude-tg-$n"
export PATH="$HOME/.bun/bin:$PATH"
tmux new-session -d -s "claude-tg-$n" "export PATH=$HOME/.bun/bin:\$PATH && claude --dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official; bash"
tmux set-option -t "claude-tg-$n" mouse on
tmux attach -t "claude-tg-$n"
