#!/bin/bash
# Launch a persistent Claude Code tmux session with remote control (access from Claude app)
n=0
while tmux has-session -t "claude-rc-$n" 2>/dev/null; do
  ((n++))
done
echo "Launching claude-rc-$n"
export PATH="$HOME/.bun/bin:$PATH"
tmux new-session -d -s "claude-rc-$n" -c "$HOME/Dropbox/Melbourne/research/sae_custom" "export PATH=$HOME/.bun/bin:\$PATH && claude remote-control --permission-mode bypassPermissions --spawn=same-dir; bash"
tmux set-option -t "claude-rc-$n" mouse on
tmux attach -t "claude-rc-$n"
