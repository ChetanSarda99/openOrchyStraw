#!/usr/bin/env bash
# review-phase.sh — Advisory review phase for agent diffs
# v0.2.0 Phase 2: #40 (Loop Review & Critique) per REVIEW-001 ADR
#
# After agents commit, selected reviewers critique diffs. Reviews are
# advisory — they never block the merge. The PM reads review output and
# decides whether to act.
#
# Provides:
#   orch_review_init      — parse review config from agents.conf column 8
#   orch_review_plan      — determine which reviews to run this cycle
#   orch_review_context   — generate review context (diff + prompt) for a pair
#   orch_review_record    — record a review verdict
#   orch_review_summary   — aggregate verdicts, write summary
#   orch_review_should_run — cost guard: check if reviews should execute

[[ -n "${_ORCH_REVIEW_PHASE_LOADED:-}" ]] && return 0
_ORCH_REVIEW_PHASE_LOADED=1

# ── State ──
declare -g -A _ORCH_REVIEW_MAP=()        # reviewer_id -> "target1,target2"
declare -g -A _ORCH_REVIEW_VERDICTS=()   # "reviewer|target" -> "approve|request-changes|comment"
declare -g -A _ORCH_REVIEW_FINDINGS=()   # "reviewer|target" -> findings text
declare -g -a _ORCH_REVIEW_PLAN=()       # "reviewer:target" pairs for this cycle
declare -g _ORCH_REVIEW_CYCLE=0
declare -g _ORCH_REVIEW_OUTPUT_DIR=""
declare -g _ORCH_REVIEW_INITIALIZED=false

# ── Helpers ──

_orch_review_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

_orch_review_log() {
    if [[ "$(type -t orch_log)" == "function" ]]; then
        orch_log "$1" "review" "$2"
    fi
}

# ── Public API ──

# orch_review_init <conf_file> [output_dir]
#   Parse agents.conf column 8 (reviews) to build the reviewer→targets map.
#   output_dir defaults to "prompts" (reviews written under prompts/<reviewer>/reviews/).
orch_review_init() {
    local conf_file="${1:?orch_review_init: conf_file required}"
    local output_dir="${2:-prompts}"

    if [[ ! -f "$conf_file" ]]; then
        _orch_review_log ERROR "Config file not found: $conf_file"
        return 1
    fi

    _ORCH_REVIEW_MAP=()
    _ORCH_REVIEW_VERDICTS=()
    _ORCH_REVIEW_FINDINGS=()
    _ORCH_REVIEW_PLAN=()
    _ORCH_REVIEW_OUTPUT_DIR="$output_dir"

    while IFS= read -r raw_line; do
        [[ -z "${raw_line// /}" ]] && continue
        local trimmed
        trimmed=$(_orch_review_trim "$raw_line")
        [[ "$trimmed" == \#* ]] && continue

        IFS='|' read -r f_id f_prompt f_ownership f_interval f_label f_priority f_depends f_reviews <<< "$raw_line"

        f_id=$(_orch_review_trim "$f_id")
        f_reviews=$(_orch_review_trim "${f_reviews:-}")

        [[ -z "$f_id" ]] && continue
        [[ -z "$f_reviews" || "$f_reviews" == "none" ]] && continue

        _ORCH_REVIEW_MAP["$f_id"]="$f_reviews"
    done < "$conf_file"

    _ORCH_REVIEW_INITIALIZED=true
    _orch_review_log INFO "Review phase initialized: ${#_ORCH_REVIEW_MAP[@]} reviewers configured"
    return 0
}

# orch_review_plan <cycle_num> <committed_agents...>
#   Determine which review pairs to execute. Only reviews where the target
#   agent actually committed this cycle are included.
#   committed_agents: space-separated list of agent IDs that committed.
#   Populates _ORCH_REVIEW_PLAN.
orch_review_plan() {
    local cycle_num="${1:?orch_review_plan: cycle_num required}"
    shift
    local -a committed=("$@")

    [[ "$_ORCH_REVIEW_INITIALIZED" != "true" ]] && return 1

    _ORCH_REVIEW_PLAN=()
    _ORCH_REVIEW_CYCLE="$cycle_num"

    # Build a set of committed agents for fast lookup
    declare -A committed_set=()
    for agent in "${committed[@]}"; do
        committed_set["$agent"]=1
    done

    for reviewer in "${!_ORCH_REVIEW_MAP[@]}"; do
        local targets="${_ORCH_REVIEW_MAP[$reviewer]}"
        IFS=',' read -ra target_list <<< "$targets"
        for target in "${target_list[@]}"; do
            target=$(_orch_review_trim "$target")
            [[ -z "$target" ]] && continue
            # Only review agents that actually committed
            if [[ -n "${committed_set[$target]+x}" ]]; then
                _ORCH_REVIEW_PLAN+=("${reviewer}:${target}")
            fi
        done
    done

    _orch_review_log INFO "Review plan: ${#_ORCH_REVIEW_PLAN[@]} reviews for cycle $cycle_num"
    return 0
}

# orch_review_context <reviewer_id> <target_id> <project_root>
#   Generate the review context for a reviewer→target pair.
#   Outputs the diff of the target's last commit + the target's prompt.
#   Returns the context as stdout. Caller pipes this to the AI agent.
orch_review_context() {
    local reviewer="${1:?orch_review_context: reviewer_id required}"
    local target="${2:?orch_review_context: target_id required}"
    local project_root="${3:?orch_review_context: project_root required}"

    # Find target's prompt file from the review map (we need to re-read conf
    # or the caller provides it). For simplicity, look in standard location.
    local target_prompt="${project_root}/prompts/${target}/${target}.txt"

    printf '# Review Request: %s (Cycle %s)\n' "$target" "$_ORCH_REVIEW_CYCLE"
    printf '**Reviewer:** %s\n\n' "$reviewer"

    printf '## Target Agent Prompt (excerpt)\n'
    if [[ -f "$target_prompt" ]]; then
        head -50 "$target_prompt" 2>/dev/null || true
    else
        printf '(prompt file not found: %s)\n' "$target_prompt"
    fi
    printf '\n'

    printf '## Changes This Cycle\n'
    printf '```diff\n'
    # Get the most recent commit by the target agent (by convention, commit
    # messages include the agent ID). Fallback: show last commit's diff.
    local diff_output
    diff_output=$(cd "$project_root" && git log --oneline -5 --all 2>/dev/null | head -1)
    if [[ -n "$diff_output" ]]; then
        # Show the diff of HEAD (most recent cycle commit)
        cd "$project_root" && git diff HEAD~1..HEAD 2>/dev/null || printf '(no diff available)\n'
    else
        printf '(no commits found)\n'
    fi
    printf '```\n\n'

    printf '## Review Template\n'
    printf 'Please evaluate the changes above and respond with:\n\n'
    printf '**Verdict:** approve | request-changes | comment\n\n'
    printf '## Findings\n'
    printf '- [BLOCKING] <description> (use for issues that must be fixed)\n'
    printf '- [SUGGESTION] <description> (use for improvements)\n'
    printf '- [NOTE] <description> (use for informational observations)\n\n'
    printf '## Summary\n'
    printf '<1-2 sentence summary of your review>\n'
}

# orch_review_record <reviewer_id> <target_id> <verdict> [findings]
#   Record a review verdict. Also writes the review file to disk.
#   verdict: approve | request-changes | comment
orch_review_record() {
    local reviewer="${1:?orch_review_record: reviewer_id required}"
    local target="${2:?orch_review_record: target_id required}"
    local verdict="${3:?orch_review_record: verdict required}"
    local findings="${4:-}"

    local key="${reviewer}|${target}"
    _ORCH_REVIEW_VERDICTS["$key"]="$verdict"
    _ORCH_REVIEW_FINDINGS["$key"]="$findings"

    # Write review file
    local review_dir="${_ORCH_REVIEW_OUTPUT_DIR}/${reviewer}/reviews"
    mkdir -p "$review_dir"

    local review_file="${review_dir}/cycle-${_ORCH_REVIEW_CYCLE}-${target}.md"
    {
        printf '# Review: %s — Cycle %s\n' "$target" "$_ORCH_REVIEW_CYCLE"
        printf '**Reviewer:** %s\n' "$reviewer"
        printf '**Verdict:** %s\n\n' "$verdict"
        if [[ -n "$findings" ]]; then
            printf '## Findings\n%s\n\n' "$findings"
        fi
        printf '## Generated\n'
        printf 'Auto-generated by review-phase.sh at %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    } > "$review_file"

    _orch_review_log INFO "Review recorded: $reviewer → $target = $verdict ($review_file)"
    return 0
}

# orch_review_summary
#   Aggregate all recorded verdicts. Print a summary suitable for shared context.
#   Returns 0 if all reviews passed, 1 if any request-changes found.
orch_review_summary() {
    local total=0
    local approvals=0
    local changes_requested=0
    local comments=0

    for key in "${!_ORCH_REVIEW_VERDICTS[@]}"; do
        local verdict="${_ORCH_REVIEW_VERDICTS[$key]}"
        (( total++ )) || true
        case "$verdict" in
            approve) (( approvals++ )) || true ;;
            request-changes) (( changes_requested++ )) || true ;;
            comment) (( comments++ )) || true ;;
        esac
    done

    printf -- '### Review Phase Summary — Cycle %s\n' "$_ORCH_REVIEW_CYCLE"
    printf -- '- **Total reviews:** %d\n' "$total"
    printf -- '- **Approved:** %d\n' "$approvals"
    printf -- '- **Changes requested:** %d\n' "$changes_requested"
    printf -- '- **Comments:** %d\n' "$comments"

    if [[ $changes_requested -gt 0 ]]; then
        printf '\n**Action required:** %d review(s) flagged issues for PM attention.\n' "$changes_requested"
        for key in "${!_ORCH_REVIEW_VERDICTS[@]}"; do
            if [[ "${_ORCH_REVIEW_VERDICTS[$key]}" == "request-changes" ]]; then
                local reviewer="${key%%|*}"
                local target="${key##*|}"
                printf '  %s flagged %s\n' "$reviewer" "$target"
            fi
        done
    fi

    if [[ $total -eq 0 ]]; then
        printf '(no reviews executed this cycle)\n'
    fi

    [[ $changes_requested -gt 0 ]] && return 1
    return 0
}

# orch_review_should_run <usage_pct>
#   Cost guard: reviews only execute when API usage < 50%.
#   usage_pct: current API usage percentage (0-100).
#   Returns 0 if reviews should run, 1 if skipped.
orch_review_should_run() {
    local usage_pct="${1:?orch_review_should_run: usage_pct required}"

    if [[ "$usage_pct" -ge 50 ]]; then
        _orch_review_log WARN "Skipping reviews: API usage at ${usage_pct}% (threshold: 50%)"
        return 1
    fi
    return 0
}

# orch_review_get_plan
#   Print the current review plan (reviewer:target pairs, one per line).
orch_review_get_plan() {
    for pair in "${_ORCH_REVIEW_PLAN[@]}"; do
        printf '%s\n' "$pair"
    done
}

# orch_review_get_reviewers
#   Print configured reviewers (one per line).
orch_review_get_reviewers() {
    for reviewer in "${!_ORCH_REVIEW_MAP[@]}"; do
        printf '%s\n' "$reviewer"
    done
}
