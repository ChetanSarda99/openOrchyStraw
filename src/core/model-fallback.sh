#!/usr/bin/env bash
# ============================================
# OrchyStraw — Model Fallback Routing Module
# ============================================
# Auto-switches agents to available models when primary hits rate limits.
# Reads usage status from shared context or env vars.
#
# Usage:
#   source src/core/model-fallback.sh
#   cli="$(orch_model_fallback_route "$agent_id" "$primary_model")"

[[ -n "${_ORCH_MODEL_FALLBACK_LOADED:-}" ]] && return 0
_ORCH_MODEL_FALLBACK_LOADED=1

# ── Default fallback chains ──────────────────────────────────────────────

# Model → CLI mapping
declare -A _MODEL_CLI=(
    [claude]="claude"
    [openai]="codex exec"
    [gemini]="gemini -p"
)

# Default fallback order per primary
declare -A _FALLBACK_CHAIN=(
    [claude]="openai gemini"
    [openai]="claude gemini"
    [gemini]="claude openai"
)

# Usage thresholds (0-100, 90+ = rate limited)
_USAGE_THRESHOLD="${ORCH_USAGE_THRESHOLD:-90}"

# ── Usage checking ───────────────────────────────────────────────────────

# Check if a model is available (not rate-limited)
# Args: $1=model_family (claude/openai/gemini)
# Returns: 0 if available, 1 if rate-limited
orch_model_fallback_check_available() {
    local model="$1"
    local usage=0

    # Check env var first: USAGE_CLAUDE=0, USAGE_GEMINI=100, etc.
    local env_var="USAGE_${model^^}"
    if [[ -n "${!env_var:-}" ]]; then
        usage="${!env_var}"
    fi

    # Check shared context file if env var not set
    if [[ "$usage" -eq 0 ]] && [[ -n "${ORCH_CONTEXT_FILE:-}" ]] && [[ -f "${ORCH_CONTEXT_FILE:-}" ]]; then
        local ctx_usage
        ctx_usage="$(grep -oE "${model}=[0-9]+" "$ORCH_CONTEXT_FILE" 2>/dev/null | head -1 | sed "s/^${model}=//")" || true
        [[ -n "$ctx_usage" ]] && usage="$ctx_usage"
    fi

    if [[ "$usage" -ge "$_USAGE_THRESHOLD" ]]; then
        return 1  # rate-limited
    fi
    return 0  # available
}

# ── Route to best available model ────────────────────────────────────────

# Find the best available model given a primary preference
# Args: $1=primary_model_family (claude/openai/gemini)
# Stdout: available model family, or "none" if all exhausted
orch_model_fallback_find() {
    local primary="${1:-claude}"

    # Try primary first
    if orch_model_fallback_check_available "$primary"; then
        echo "$primary"
        return 0
    fi

    # Try fallback chain
    local chain="${_FALLBACK_CHAIN[$primary]:-claude openai gemini}"
    for fallback in $chain; do
        if orch_model_fallback_check_available "$fallback"; then
            echo "$fallback"
            return 0
        fi
    done

    echo "none"
    return 1
}

# Get the CLI command for a model family
# Args: $1=model_family
# Stdout: CLI command string
orch_model_fallback_cli() {
    local model="${1:-claude}"
    echo "${_MODEL_CLI[$model]:-claude}"
}

# Full route: find available model and return its CLI
# Args: $1=agent_id (for logging), $2=primary_model_family
# Stdout: CLI command to use
# Returns: 0 if routed, 1 if all models exhausted
orch_model_fallback_route() {
    local agent_id="${1:-unknown}"
    local primary="${2:-claude}"

    local available
    available="$(orch_model_fallback_find "$primary")"

    if [[ "$available" == "none" ]]; then
        printf 'WARN: all models exhausted for agent %s (primary=%s)\n' "$agent_id" "$primary" >&2
        # Last resort: return primary CLI anyway (will likely fail with rate limit)
        orch_model_fallback_cli "$primary"
        return 1
    fi

    if [[ "$available" != "$primary" ]]; then
        printf 'INFO: agent %s falling back %s → %s\n' "$agent_id" "$primary" "$available" >&2
    fi

    orch_model_fallback_cli "$available"
    return 0
}

# ── Custom chain configuration ───────────────────────────────────────────

# Override the fallback chain for a model
# Args: $1=model_family, $2=space-separated fallback list
orch_model_fallback_set_chain() {
    local model="$1"
    shift
    _FALLBACK_CHAIN[$model]="$*"
}

# Override the CLI for a model
# Args: $1=model_family, $2=cli_command
orch_model_fallback_set_cli() {
    local model="$1" cli="$2"
    _MODEL_CLI[$model]="$cli"
}

# Set usage threshold
# Args: $1=threshold (0-100)
orch_model_fallback_set_threshold() {
    _USAGE_THRESHOLD="${1:-90}"
}
