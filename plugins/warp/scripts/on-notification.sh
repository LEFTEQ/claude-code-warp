#!/bin/bash
# Hook script for Claude Code Notification event
# Sends a structured Warp notification when Claude has been idle or is waiting
# on the user.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/should-use-structured.sh"

# Legacy fallback for old Warp versions
if ! should_use_structured; then
    [ "$TERM_PROGRAM" = "WarpTerminal" ] && exec "$SCRIPT_DIR/legacy/on-notification.sh"
    exit 0
fi

source "$SCRIPT_DIR/build-payload.sh"

# Read hook input from stdin
INPUT=$(cat)

# Extract notification-specific fields
NOTIF_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"' 2>/dev/null)
MSG=$(echo "$INPUT" | jq -r '.message // "Input needed"' 2>/dev/null)
[ -z "$MSG" ] && MSG="Input needed"

# Map the notification type onto a protocol event. Most types are already event
# names and pass straight through; `agent_needs_input` is not, and would reach
# Warp as an unrecognised event that leaves the session looking like it is still
# working, when it is in fact waiting on the user.
case "$NOTIF_TYPE" in
    agent_needs_input) EVENT="question_asked" ;;
    *)                 EVENT="$NOTIF_TYPE" ;;
esac

BODY=$(build_payload "$INPUT" "$EVENT" \
    --arg summary "$MSG")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
