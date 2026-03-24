#!/bin/bash
# Launch a persistent Claude Code tmux session with Telegram channel
n=0
while tmux has-session -t "claude-tg-$n" 2>/dev/null; do
  ((n++))
done
echo "Launching claude-tg-$n"
tmux new-session -d -s "claude-tg-$n" "claude --dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official; bash"
tmux set-option -t "claude-tg-$n" mouse on
tmux attach -t "claude-tg-$n"
