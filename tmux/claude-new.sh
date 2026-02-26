#!/bin/bash
# Launch a new Claude Code tmux session with auto-incrementing name
n=0
while tmux has-session -t "claude-$n" 2>/dev/null; do
  ((n++))
done
echo "Launching claude-$n"
tmux new-session -d -s "claude-$n" "claude --dangerously-skip-permissions; bash"
tmux attach -t "claude-$n"
