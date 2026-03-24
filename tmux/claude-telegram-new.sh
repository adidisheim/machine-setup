#!/bin/bash
# Launch a persistent Claude Code tmux session with Telegram channel
# Uses --plugin-dir to load the telegram plugin directly (bypasses broken `claude plugin install`)
n=0
while tmux has-session -t "claude-tg-$n" 2>/dev/null; do
  ((n++))
done
echo "Launching claude-tg-$n"
export PATH="$HOME/.bun/bin:$PATH"
TELEGRAM_PLUGIN="$HOME/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram"
tmux new-session -d -s "claude-tg-$n" "export PATH=$HOME/.bun/bin:\$PATH && claude --dangerously-skip-permissions --plugin-dir $TELEGRAM_PLUGIN; bash"
tmux set-option -t "claude-tg-$n" mouse on
tmux attach -t "claude-tg-$n"
