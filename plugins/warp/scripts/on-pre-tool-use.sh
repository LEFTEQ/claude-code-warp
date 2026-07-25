#!/bin/bash
# Hook script for Claude Code PreToolUse event, scoped to the tools that stop
# and wait for a human: AskUserQuestion and ExitPlanMode.
#
# Without this, a session that is blocked on a question or a plan approval
# reports nothing, so Warp shows it as still working. PermissionRequest does not
# cover these: it fires for tool permission only, and it never fires at all when
# the user runs with permissions.defaultMode=bypassPermissions — which is
# precisely the setup where a question is the *only* thing that stops the agent.
#
# The matching unblock is the existing PostToolUse hook: `tool_complete` moves a
# blocked session back to running, so answering the question clears the state.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/should-use-structured.sh"

# No legacy equivalent for this hook
if ! should_use_structured; then
    exit 0
fi

source "$SCRIPT_DIR/build-payload.sh"

# Read hook input from stdin
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# A one-line description of what the user is being asked, per tool.
# AskUserQuestion carries the questions themselves; ExitPlanMode has no useful
# field, so it gets a fixed label.
SUMMARY=$(echo "$INPUT" | jq -r '
  def clean: gsub("\\s+"; " ") | .[0:160];
  if .tool_name == "AskUserQuestion" then
    ([.tool_input.questions[]? | .question] | join(" · ") | clean)
  elif .tool_name == "ExitPlanMode" then
    "Plan ready for your approval"
  else
    ""
  end
' 2>/dev/null)

# Warp falls back to its own wording when the summary is empty, so an
# unparseable payload still produces a correct blocked state.
[ -z "$SUMMARY" ] && SUMMARY="Waiting for your answer"

BODY=$(build_payload "$INPUT" "question_asked" \
    --arg summary "$SUMMARY" \
    --arg tool_name "$TOOL_NAME")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
