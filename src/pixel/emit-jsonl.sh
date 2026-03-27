#!/usr/bin/env bash
# OrchyStraw — Synthetic JSONL Emitter for Pixel Agents
# Source this file in auto-agent.sh to emit events that Pixel Agents visualizes.
#
# Usage:
#   source src/pixel/emit-jsonl.sh
#   pixel_init                          # set up session dirs, clear old data
#   pixel_emit "06-backend" write_file '{"path":"src/core/engine.sh"}'
#   pixel_emit "06-backend" read_file  '{"path":"prompts/00-shared-context/context.md"}'
#   pixel_emit "06-backend" bash       '{"command":"npm test"}'
#   pixel_end  "06-backend"            # agent goes idle (turn end)
#
# Pixel Agents watches ~/.claude/projects/ for JSONL files and animates characters.
# We write synthetic events in the same format so characters appear during cycles.

# ── Configuration ──────────────────────────────────────────────────────────────

PIXEL_SESSION_DIR="${PIXEL_SESSION_DIR:-$HOME/.claude/projects/orchystraw}"
PIXEL_ENABLED="${PIXEL_ENABLED:-1}"

# ── Internal helpers ───────────────────────────────────────────────────────────

_pixel_enabled() {
  [[ "$PIXEL_ENABLED" == "1" ]]
}

_pixel_agent_dir() {
  local agent_id="$1"
  echo "${PIXEL_SESSION_DIR}/${agent_id}"
}

_pixel_session_file() {
  local agent_id="$1"
  echo "$(_pixel_agent_dir "$agent_id")/session.jsonl"
}

_pixel_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ"
}

# ── Public API ─────────────────────────────────────────────────────────────────

# Initialize pixel session dirs and clear old JSONL data.
# Call once at cycle start.
pixel_init() {
  _pixel_enabled || return 0
  mkdir -p "$PIXEL_SESSION_DIR"
  # Clear previous cycle's JSONL files
  find "$PIXEL_SESSION_DIR" -name "session.jsonl" -delete 2>/dev/null
  return 0
}

# Emit a tool_use event (agent does something → character animates).
#
# Args:
#   $1 — agent_id   (e.g. "06-backend", "03-pm")
#   $2 — tool_name  (write_file | read_file | bash | grep | list_files)
#   $3 — input_json (JSON object with tool-specific fields, e.g. '{"path":"src/foo.sh"}')
#
# Animation mapping:
#   write_file → typing     read_file/grep → reading     bash → running
pixel_emit() {
  _pixel_enabled || return 0
  local agent_id="$1"
  local tool_name="$2"
  local input_json="${3:-"{}"}"

  local dir
  dir="$(_pixel_agent_dir "$agent_id")"
  mkdir -p "$dir"

  local session_file
  session_file="$(_pixel_session_file "$agent_id")"

  # Pixel Agents format: assistant message with tool_use content block
  printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"orchystraw-%s-%s","name":"%s","input":%s}]},"timestamp":"%s"}\n' \
    "$agent_id" "$(date +%s%N 2>/dev/null || date +%s)" \
    "$tool_name" \
    "$input_json" \
    "$(_pixel_timestamp)" \
    >> "$session_file"
}

# Emit a tool_result event (confirms the tool_use completed).
# Keeps Pixel Agents' parser happy — some parsers expect user/tool_result after assistant/tool_use.
pixel_emit_result() {
  _pixel_enabled || return 0
  local agent_id="$1"
  local tool_use_id="${2:-orchystraw}"
  local result_text="${3:-OK}"

  local session_file
  session_file="$(_pixel_session_file "$agent_id")"
  [[ -f "$session_file" ]] || return 0

  printf '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"%s","content":"%s"}]},"timestamp":"%s"}\n' \
    "$tool_use_id" \
    "$result_text" \
    "$(_pixel_timestamp)" \
    >> "$session_file"
}

# Emit a speech bubble event (agent says something).
# Shows as a text bubble above the character.
pixel_say() {
  _pixel_enabled || return 0
  local agent_id="$1"
  local message="$2"

  local session_file
  session_file="$(_pixel_session_file "$agent_id")"
  local dir
  dir="$(_pixel_agent_dir "$agent_id")"
  mkdir -p "$dir"

  printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]},"timestamp":"%s"}\n' \
    "$message" \
    "$(_pixel_timestamp)" \
    >> "$session_file"
}

# Emit a turn-end event (agent finishes → character goes idle / walks away).
pixel_end() {
  _pixel_enabled || return 0
  local agent_id="$1"
  local result="${2:-done}"

  local session_file
  session_file="$(_pixel_session_file "$agent_id")"
  [[ -f "$session_file" ]] || return 0

  printf '{"type":"result","subtype":"success","result":"%s","session_id":"orchystraw-%s","timestamp":"%s"}\n' \
    "$result" \
    "$agent_id" \
    "$(_pixel_timestamp)" \
    >> "$session_file"
}

# ── Convenience wrappers (map to OrchyStraw lifecycle) ─────────────────────────

# Agent starts working — reading their prompt
pixel_agent_start() {
  local agent_id="$1"
  local prompt_path="$2"
  pixel_say "$agent_id" "Starting work..."
  pixel_emit "$agent_id" "read_file" "{\"path\":\"$prompt_path\"}"
}

# Agent reads shared context
pixel_agent_read_context() {
  local agent_id="$1"
  pixel_emit "$agent_id" "read_file" '{"path":"prompts/00-shared-context/context.md"}'
}

# Agent is coding (writing files in their ownership area)
pixel_agent_coding() {
  local agent_id="$1"
  local file_path="${2:-src/}"
  pixel_emit "$agent_id" "write_file" "{\"path\":\"$file_path\"}"
}

# Agent runs a command (tests, build, etc.)
pixel_agent_running() {
  local agent_id="$1"
  local command="${2:-running task}"
  pixel_emit "$agent_id" "bash" "{\"command\":\"$command\"}"
}

# Agent writes to shared context (shows speech bubble + write)
pixel_agent_update_context() {
  local agent_id="$1"
  local status_msg="$2"
  pixel_say "$agent_id" "$status_msg"
  pixel_emit "$agent_id" "write_file" '{"path":"prompts/00-shared-context/context.md"}'
}

# PM visits an agent's desk (writes to their prompt)
pixel_pm_visit() {
  local target_agent_id="$1"
  local prompt_path="$2"
  pixel_say "03-pm" "Updating $target_agent_id..."
  pixel_emit "03-pm" "read_file" "{\"path\":\"$prompt_path\"}"
  pixel_emit "03-pm" "write_file" "{\"path\":\"$prompt_path\"}"
}

# Agent finishes — update context and go idle
pixel_agent_done() {
  local agent_id="$1"
  local summary="${2:-Finished tasks}"
  pixel_agent_update_context "$agent_id" "$summary"
  pixel_end "$agent_id"
}
