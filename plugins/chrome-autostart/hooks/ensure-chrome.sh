#!/bin/bash
# PreToolUse hook: opens Chrome if it is closed, then waits for the
# Claude extension to connect before a claude-in-chrome tool runs.
#
# Settings (environment variables):
#   CHROME_AUTOSTART_CMD      command that opens Chrome (default: first found
#                             of google-chrome, google-chrome-stable, chromium)
#   CHROME_AUTOSTART_TIMEOUT  seconds to wait for the extension (default: 20)

BRIDGE_DIR="/tmp/claude-mcp-browser-bridge-$(whoami)"
TIMEOUT="${CHROME_AUTOSTART_TIMEOUT:-20}"

# The extension's native host creates <pid>.sock here while it is connected.
bridge_up() {
  for sock in "$BRIDGE_DIR"/*.sock; do
    [ -S "$sock" ] || continue
    pid=$(basename "$sock" .sock)
    kill -0 "$pid" 2>/dev/null && return 0
  done
  return 1
}

bridge_up && exit 0

if ! pgrep -x chrome >/dev/null; then
  cmd="$CHROME_AUTOSTART_CMD"
  if [ -z "$cmd" ]; then
    for c in google-chrome google-chrome-stable chromium chromium-browser; do
      command -v "$c" >/dev/null && { cmd="$c"; break; }
    done
  fi
  if [ -z "$cmd" ]; then
    echo "chrome-autostart: no Chrome found. Set CHROME_AUTOSTART_CMD." >&2
    exit 0
  fi
  setsid $cmd >/dev/null 2>&1 < /dev/null &
fi

for _ in $(seq 1 $((TIMEOUT * 2))); do
  # Give Claude Code a moment to see the new connection.
  bridge_up && { sleep 3; exit 0; }
  sleep 0.5
done

echo "chrome-autostart: Chrome is open but the Claude extension did not connect within ${TIMEOUT}s." >&2
exit 0
