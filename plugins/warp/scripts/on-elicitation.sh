#!/bin/bash
# Hook script for Claude Code Elicitation event
# Sends a structured Warp notification when an MCP server asks the user for
# input, which blocks the session on a human exactly like a question does.
#
# Elicitation has no PostToolUse counterpart to unblock it. The session returns
# to running on the next `prompt_submit` or `tool_complete`, both of which the
# plugin already sends.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/should-use-structured.sh"

# No legacy equivalent for this hook
if ! should_use_structured; then
    exit 0
fi

source "$SCRIPT_DIR/build-payload.sh"
source "$SCRIPT_DIR/blocked-state.sh"

# Read hook input from stdin
INPUT=$(cat)

# The prompt shown to the user, wherever the event carries it.
SUMMARY=$(echo "$INPUT" | jq -r '
  ((.message // .params.message // .prompt // "") | gsub("\\s+"; " ") | .[0:160])
' 2>/dev/null)

[ -z "$SUMMARY" ] && SUMMARY="Waiting for your input"

BODY=$(build_payload "$INPUT" "question_asked" \
    --arg summary "$SUMMARY")

mark_blocked "$INPUT"
"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
