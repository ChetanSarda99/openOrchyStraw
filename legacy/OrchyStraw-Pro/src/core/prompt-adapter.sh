#!/usr/bin/env bash
# ============================================
# OrchyStraw — Prompt Adapter Module
# ============================================
# Adapts agent prompts per model for optimal performance.
# Claude, OpenAI (GPT), and Gemini have different optimal prompt structures.
#
# Usage:
#   source src/core/prompt-adapter.sh
#   adapted="$(orch_prompt_adapter_wrap "$model" "$prompt" "$role")"

[[ -n "${_ORCH_PROMPT_ADAPTER_LOADED:-}" ]] && return 0
_ORCH_PROMPT_ADAPTER_LOADED=1

# ── Model detection ──────────────────────────────────────────────────────

# Detect model family from CLI name or model string
# Returns: claude, openai, gemini, or unknown
orch_prompt_adapter_detect() {
    local model="${1:-claude}"
    case "$model" in
        claude*|opus*|sonnet*|haiku*)  echo "claude" ;;
        gpt*|openai*|codex*|o1*|o3*)  echo "openai" ;;
        gemini*|palm*)                  echo "gemini" ;;
        *)                              echo "unknown" ;;
    esac
}

# ── Claude adapter ───────────────────────────────────────────────────────

# Claude optimal: system prompt via XML tags, role in <role>, task in <task>
_adapt_claude() {
    local prompt="$1" role="${2:-assistant}"
    cat <<ADAPTED
<role>
You are ${role}. Follow all instructions precisely.
</role>

<task>
${prompt}
</task>

<guidelines>
- Be concise and direct
- Show your reasoning in <thinking> tags when the task is complex
- Prefer editing existing files over creating new ones
- Stay within your file ownership boundaries
</guidelines>
ADAPTED
}

# ── OpenAI adapter ───────────────────────────────────────────────────────

# GPT optimal: system message style, markdown headers, numbered instructions
_adapt_openai() {
    local prompt="$1" role="${2:-assistant}"
    cat <<ADAPTED
# System
You are ${role}.

# Instructions
${prompt}

# Output Requirements
1. Be concise and direct in your responses
2. Show reasoning before conclusions
3. Prefer editing existing files over creating new ones
4. Stay within your file ownership boundaries
ADAPTED
}

# ── Gemini adapter ───────────────────────────────────────────────────────

# Gemini optimal: clear sections, bullet points, explicit persona
_adapt_gemini() {
    local prompt="$1" role="${2:-assistant}"
    cat <<ADAPTED
**Persona:** You are ${role}.

**Context:**
${prompt}

**Rules:**
- Be concise and direct
- Reason step by step for complex tasks
- Prefer editing existing files over creating new ones
- Stay within your file ownership boundaries
- When uncertain, state what you know and what you're unsure about
ADAPTED
}

# ── Public API ───────────────────────────────────────────────────────────

# Wrap a prompt for a specific model
# Args: $1=model (claude/openai/gemini/auto), $2=prompt, $3=role (optional)
# Stdout: adapted prompt
orch_prompt_adapter_wrap() {
    local model="${1:-claude}"
    local prompt="${2:-}"
    local role="${3:-assistant}"

    [[ -z "$prompt" ]] && { echo ""; return 0; }

    local family
    family="$(orch_prompt_adapter_detect "$model")"

    case "$family" in
        claude)  _adapt_claude "$prompt" "$role" ;;
        openai)  _adapt_openai "$prompt" "$role" ;;
        gemini)  _adapt_gemini "$prompt" "$role" ;;
        *)
            # Unknown model — return prompt as-is with minimal wrapper
            printf '%s\n\nYou are %s. Follow instructions precisely.\n' "$prompt" "$role"
            ;;
    esac
}

# Get the model family for an agent from agents.conf
# Args: $1=agent_id, $2=agents_conf_path
# Stdout: model family (claude/openai/gemini)
orch_prompt_adapter_agent_model() {
    local agent_id="${1:-}" conf="${2:-}"

    [[ -z "$agent_id" ]] && { echo "claude"; return 0; }
    [[ -z "$conf" ]] || [[ ! -f "$conf" ]] && { echo "claude"; return 0; }

    # Parse agents.conf for model field
    # Format: id|name|prompt|interval|model (model is optional 5th field)
    local model_field
    model_field="$(grep "^${agent_id}|" "$conf" 2>/dev/null | cut -d'|' -f5 | tr -d '[:space:]')"

    if [[ -n "$model_field" ]]; then
        orch_prompt_adapter_detect "$model_field"
    else
        echo "claude"  # default
    fi
}

# Batch-adapt: read prompt from file, write adapted version to stdout
# Args: $1=model, $2=prompt_file, $3=role
orch_prompt_adapter_file() {
    local model="${1:-claude}"
    local prompt_file="${2:-}"
    local role="${3:-assistant}"

    [[ -f "$prompt_file" ]] || { echo "ERROR: prompt file not found: $prompt_file" >&2; return 1; }

    local prompt
    prompt="$(cat "$prompt_file")"
    orch_prompt_adapter_wrap "$model" "$prompt" "$role"
}
