#!/bin/bash
# Launch a persistent Claude Code tmux session (survives SSH disconnects)
n=0
while tmux has-session -t "claude-$n" 2>/dev/null; do
  ((n++))
done
echo "Launching claude-$n"
tmux new-session -d -s "claude-$n" "ANTHROPIC_MODEL='claude-opus-4-7[1m]' claude --dangerously-skip-permissions --model 'claude-opus-4-7[1m]'; bash"
tmux set-option -t "claude-$n" mouse on
# Set effort to max by default
sleep 0.5
tmux send-keys -t "claude-$n" "/effort max" Enter
sleep 0.3
tmux send-keys -t "claude-$n" "/compact auto" Enter
tmux attach -t "claude-$n"
