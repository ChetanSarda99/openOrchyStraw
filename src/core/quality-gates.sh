#!/usr/bin/env bash
# quality-gates.sh — Pre-commit quality checks for agent output
# v0.2.0: #145 (Quality gates — validate agent output before commit)
#
# Provides:
#   orch_quality_init    — set thresholds
#   orch_quality_check   — validate agent output meets minimum bar

[[ -n "${_ORCH_QUALITY_GATES_LOADED:-}" ]] && return 0
_ORCH_QUALITY_GATES_LOADED=1

declare -g _ORCH_QUALITY_MIN_OUTPUT="${ORCH_QUALITY_MIN_OUTPUT:-200}"
declare -g _ORCH_QUALITY_MAX_OUTPUT="${ORCH_QUALITY_MAX_OUTPUT:-5000000}"
declare -g -A _ORCH_QUALITY_AGENT_OWNERSHIP=()
declare -g _ORCH_QUALITY_PROJECT_ROOT=""

_orch_quality_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "quality" "$2"
    fi
}

orch_quality_init() {
    local project_root="${1:?orch_quality_init: project_root required}"
    local conf_file="${2:-}"

    _ORCH_QUALITY_PROJECT_ROOT="$project_root"

    if [[ -n "$conf_file" && -f "$conf_file" ]]; then
        while IFS= read -r raw_line; do
            [[ -z "${raw_line// /}" ]] && continue
            [[ "$raw_line" =~ ^[[:space:]]*# ]] && continue
            IFS='|' read -r f_id _ f_ownership _ _ _ _ _ _ <<< "$raw_line"
            f_id="${f_id#"${f_id%%[![:space:]]*}"}"
            f_id="${f_id%"${f_id##*[![:space:]]}"}"
            f_ownership="${f_ownership#"${f_ownership%%[![:space:]]*}"}"
            f_ownership="${f_ownership%"${f_ownership##*[![:space:]]}"}"
            [[ -n "$f_id" ]] && _ORCH_QUALITY_AGENT_OWNERSHIP["$f_id"]="$f_ownership"
        done < "$conf_file"
    fi
}

# orch_quality_check <agent_id> <log_file>
#   Returns 0 if output passes quality gates, 1 if it fails.
#   Checks: output size, no empty output, files within ownership.
orch_quality_check() {
    local agent_id="${1:?orch_quality_check: agent_id required}"
    local log_file="${2:-}"

    if [[ -n "$log_file" && -f "$log_file" ]]; then
        local log_size
        log_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)

        if [[ "$log_size" -lt "$_ORCH_QUALITY_MIN_OUTPUT" ]]; then
            _orch_quality_log WARN "[$agent_id] Output too small (${log_size}B < ${_ORCH_QUALITY_MIN_OUTPUT}B) — quality gate FAIL"
            return 1
        fi

        if [[ "$log_size" -gt "$_ORCH_QUALITY_MAX_OUTPUT" ]]; then
            _orch_quality_log WARN "[$agent_id] Output suspiciously large (${log_size}B > ${_ORCH_QUALITY_MAX_OUTPUT}B) — quality gate FAIL"
            return 1
        fi
    fi

    if [[ -z "$_ORCH_QUALITY_PROJECT_ROOT" ]]; then
        return 0
    fi

    local ownership="${_ORCH_QUALITY_AGENT_OWNERSHIP[$agent_id]:-}"
    if [[ -z "$ownership" || "$ownership" == "none" ]]; then
        return 0
    fi

    local changed_files
    changed_files=$(git -C "$_ORCH_QUALITY_PROJECT_ROOT" diff --name-only HEAD 2>/dev/null)
    [[ -z "$changed_files" ]] && return 0

    IFS=' ' read -ra owned_paths <<< "$ownership"
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local matched=false
        for path in "${owned_paths[@]}"; do
            [[ "$path" == !* ]] && continue
            if [[ "$file" == "$path"* ]]; then
                matched=true
                break
            fi
        done
        if [[ "$matched" == "false" ]]; then
            _orch_quality_log WARN "[$agent_id] Wrote outside ownership: $file — quality gate FAIL"
            return 1
        fi
    done <<< "$changed_files"

    return 0
}
