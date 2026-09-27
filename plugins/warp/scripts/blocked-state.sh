#!/bin/bash
# Per-session markers for "Warp shows this session as Blocked".
#
# Warp leaves the Blocked state only on prompt_submit, stop, or tool_complete,
# and ignores tool_complete otherwise. The PostToolUse hook cannot narrow its
# matcher: a permission prompt or an MCP elicitation can gate any tool, and the
# gated tool's PostToolUse is the only unblock signal. So it matches every tool
# call and must cost nothing while no session is blocked:
#
#   - hooks that report a Blocked state call mark_blocked;
#   - on-post-tool-use.sh exits at once unless any_blocked (builtins only),
#     then unless its own session's marker exists;
#   - hooks whose event leaves the Blocked state call clear_blocked.
#
# Usage:
#   source "$SCRIPT_DIR/blocked-state.sh"
#   mark_blocked "$INPUT"     # or clear_blocked "$INPUT"

# Per user and owner-only: with TMPDIR unset this sits in a shared /tmp, where
# another local user could pre-create the directory and plant symlinks.
BLOCKED_DIR="${TMPDIR:-/tmp}/claude-warp-blocked-${UID}"

# Marker path for the session named in the hook input ("unknown" when the
# input carries no session_id, so mark and clear still pair up).
_blocked_marker() {
    local sid
    sid=$(echo "$1" | jq -r '.session_id // empty' 2>/dev/null)
    sid="${sid//[^A-Za-z0-9_-]/}"
    printf '%s/%s' "$BLOCKED_DIR" "${sid:-unknown}"
}

mark_blocked() {
    local marker
    mkdir -p -m 700 "$BLOCKED_DIR" 2>/dev/null
    # Never write through a directory or marker someone else controls.
    [ -d "$BLOCKED_DIR" ] && [ ! -L "$BLOCKED_DIR" ] && [ -O "$BLOCKED_DIR" ] || return 0
    marker=$(_blocked_marker "$1")
    [ -L "$marker" ] || : > "$marker" 2>/dev/null
    return 0
}

clear_blocked() {
    local marker
    marker=$(_blocked_marker "$1")
    [ -e "$marker" ] && rm -f "$marker"
    return 0
}

# Runs on every tool call: shell builtins only, no subshell, no jq.
any_blocked() {
    local f
    for f in "$BLOCKED_DIR"/*; do
        [ -e "$f" ] && return 0
    done
    return 1
}

# A session killed while blocked never clears its marker, which would keep the
# PostToolUse fast path open for everyone. Drop markers older than a day.
sweep_stale_blocked() {
    [ -d "$BLOCKED_DIR" ] && find "$BLOCKED_DIR" -type f -mmin +1440 -delete 2>/dev/null
    return 0
}
