#!/usr/bin/env bash
# review-phase.sh — Advisory review phase for agent diffs
# v0.3.0 Phase 2: #40 (Loop Review & Critique) per REVIEW-001 ADR
#         v0.3 adds: structured rubrics, multi-reviewer consensus,
#         actionable feedback templates, severity classification
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
#   orch_review_rubric    — generate structured review rubric (v0.3)
#   orch_review_consensus — compute multi-reviewer consensus (v0.3)
#   orch_review_feedback_template — generate actionable feedback (v0.3)
#   orch_review_record_finding    — record individual finding with severity (v0.3)
#   orch_review_findings_by_severity — list findings grouped by severity (v0.3)

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

# v0.3 Structured rubric state
declare -g -A _ORCH_REVIEW_SCORES=()       # "reviewer|target|dimension" -> score (1-5)
declare -g -a _ORCH_REVIEW_DIMENSIONS=()   # list of review dimensions

# v0.3 Individual findings with severity
declare -g -a _ORCH_REVIEW_FINDING_LIST=() # indexed findings: "severity|reviewer|target|description"

# v0.3 Default review dimensions (can be overridden)
_ORCH_REVIEW_DIMENSIONS=(correctness security performance readability standards)

# v0.3 Severity levels
declare -g -a _ORCH_REVIEW_SEVERITIES=(critical major minor suggestion note)

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
    # RP-04: reject path traversal in agent IDs
    if [[ "$reviewer" == *".."* || "$target" == *".."* ]]; then
        _orch_review_log ERROR "Path traversal detected in agent ID"
        return 1
    fi

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
    printf -- '- [BLOCKING] <description> (use for issues that must be fixed)\n'
    printf -- '- [SUGGESTION] <description> (use for improvements)\n'
    printf -- '- [NOTE] <description> (use for informational observations)\n\n'
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

    # RP-01: validate verdict
    case "$verdict" in
        approve|request-changes|comment) ;;
        *)
            _orch_review_log WARN "Invalid verdict '$verdict' — must be approve|request-changes|comment"
            return 1
            ;;
    esac

    # RP-04: reject path traversal
    if [[ "$reviewer" == *".."* || "$target" == *".."* ]]; then
        _orch_review_log ERROR "Path traversal detected in agent ID"
        return 1
    fi

    local key="${reviewer}|${target}"
    _ORCH_REVIEW_VERDICTS["$key"]="$verdict"
    _ORCH_REVIEW_FINDINGS["$key"]="$findings"

    # Write review file
    local review_dir="${_ORCH_REVIEW_OUTPUT_DIR}/${reviewer}/reviews"
    if ! mkdir -p "$review_dir"; then
        _orch_review_log ERROR "Failed to create review directory: $review_dir"
        return 1
    fi

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
    } > "$review_file" || {
        _orch_review_log ERROR "Failed to write review file: $review_file"
        return 1
    }

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

    # RP-02: summary field
    if [[ $total -eq 0 ]]; then
        printf '**Summary:** No reviews executed this cycle.\n'
    elif [[ $changes_requested -gt 0 ]]; then
        printf '**Summary:** NEEDS ATTENTION — %d of %d review(s) flagged issues.\n' "$changes_requested" "$total"
    else
        printf '**Summary:** ALL CLEAR — %d review(s) passed.\n' "$total"
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

# ══════════════════════════════════════════════════
# v0.3 Structured Rubrics
# ══════════════════════════════════════════════════

# orch_review_rubric [target_id]
#   Generate a structured review rubric template. Output is markdown suitable
#   for inclusion in the review context sent to a reviewer agent.
orch_review_rubric() {
    local target="${1:-agent}"

    printf '## Structured Review Rubric\n'
    printf 'Rate each dimension 1-5 (1=critical issues, 5=excellent):\n\n'

    printf '| Dimension | Score (1-5) | Notes |\n'
    printf '|-----------|-------------|-------|\n'

    for dim in "${_ORCH_REVIEW_DIMENSIONS[@]}"; do
        local guidance=""
        case "$dim" in
            correctness)  guidance="Logic bugs, edge cases, error handling" ;;
            security)     guidance="Auth, injection, secrets, OWASP patterns" ;;
            performance)  guidance="Hot paths, complexity, resource usage" ;;
            readability)  guidance="Naming, structure, comments, complexity" ;;
            standards)    guidance="Project conventions, ownership rules, style" ;;
            *)            guidance="Custom dimension" ;;
        esac
        printf '| **%s** | _/5 | %s |\n' "$dim" "$guidance"
    done

    printf '\n'
    printf '%s\n' '## Findings (use severity prefixes)'
    printf '%s\n' '- [CRITICAL] <description> — Must fix before merge, breaks functionality'
    printf '%s\n' '- [MAJOR] <description> — Should fix, significant quality issue'
    printf '%s\n' '- [MINOR] <description> — Nice to fix, minor quality concern'
    printf '%s\n' '- [SUGGESTION] <description> — Optional improvement idea'
    printf '%s\n\n' '- [NOTE] <description> — Informational observation'

    printf '%s\n' '## Action Items'
    printf '%s\n' 'List specific, actionable items the agent should address:'
    printf '%s\n\n' '1. | 2. | 3. '

    printf '%s\n' '## Summary Verdict'
    printf '%s\n' '**Verdict:** approve | request-changes | comment'
    printf '%s\n' '**Confidence:** high | medium | low'
    printf '%s\n' '**Summary:** <1-2 sentences>'
}

# orch_review_set_dimensions <dimension1> <dimension2> ...
#   Override the default review dimensions.
orch_review_set_dimensions() {
    _ORCH_REVIEW_DIMENSIONS=("$@")
}

# orch_review_record_score <reviewer_id> <target_id> <dimension> <score>
#   Record a rubric score for a specific dimension (1-5).
orch_review_record_score() {
    local reviewer="${1:?record_score: reviewer required}"
    local target="${2:?record_score: target required}"
    local dimension="${3:?record_score: dimension required}"
    local score="${4:?record_score: score required}"

    [[ ! "$score" =~ ^[1-5]$ ]] && {
        _orch_review_log WARN "Invalid rubric score: $score (must be 1-5)"
        return 1
    }

    _ORCH_REVIEW_SCORES["${reviewer}|${target}|${dimension}"]="$score"
    return 0
}

# orch_review_rubric_summary <target_id>
#   Print rubric score summary for a target across all reviewers.
orch_review_rubric_summary() {
    local target="${1:?rubric_summary: target required}"

    printf '### Rubric Summary: %s\n' "$target"
    printf '| Dimension | '

    # Collect reviewers who reviewed this target
    local -a reviewers=()
    local key
    for key in "${!_ORCH_REVIEW_SCORES[@]}"; do
        if [[ "$key" == *"|${target}|"* ]]; then
            local rev="${key%%|*}"
            local found=false
            local r
            for r in "${reviewers[@]+"${reviewers[@]}"}"; do
                [[ "$r" == "$rev" ]] && found=true
            done
            [[ "$found" == false ]] && reviewers+=("$rev")
        fi
    done

    for rev in "${reviewers[@]+"${reviewers[@]}"}"; do
        printf '%s | ' "$rev"
    done
    printf 'Avg |\n'

    printf '%s' '|---|'
    for _ in "${reviewers[@]+"${reviewers[@]}"}"; do printf '%s' '---|'; done
    printf '%s\n' '---|'

    for dim in "${_ORCH_REVIEW_DIMENSIONS[@]}"; do
        printf '| %s | ' "$dim"
        local total=0 count=0
        for rev in "${reviewers[@]+"${reviewers[@]}"}"; do
            local score="${_ORCH_REVIEW_SCORES[${rev}|${target}|${dim}]:-}"
            if [[ -n "$score" ]]; then
                printf '%s | ' "$score"
                total=$((total + score))
                count=$((count + 1))
            else
                printf '%s' '- | '
            fi
        done
        if [[ "$count" -gt 0 ]]; then
            local avg_val
            avg_val=$(echo "scale=1; $total / $count" | bc 2>/dev/null || echo "$((total / count))")
            printf '%s |\n' "$avg_val"
        else
            printf '%s\n' '- |'
        fi
    done
}

# ══════════════════════════════════════════════════
# v0.3 Multi-Reviewer Consensus
# ══════════════════════════════════════════════════

# orch_review_consensus <target_id>
#   Compute consensus across all reviewers for a target.
#   Returns: approve (all approve), request-changes (any request-changes),
#   mixed (disagreement), comment (only comments).
#   Prints the consensus verdict.
orch_review_consensus() {
    local target="${1:?consensus: target required}"

    local approvals=0 changes=0 comments=0 total=0

    for key in "${!_ORCH_REVIEW_VERDICTS[@]}"; do
        if [[ "$key" == *"|${target}" ]]; then
            local verdict="${_ORCH_REVIEW_VERDICTS[$key]}"
            total=$((total + 1))
            case "$verdict" in
                approve) approvals=$((approvals + 1)) ;;
                request-changes) changes=$((changes + 1)) ;;
                comment) comments=$((comments + 1)) ;;
            esac
        fi
    done

    if [[ "$total" -eq 0 ]]; then
        printf 'no-reviews\n'
        return 0
    fi

    if [[ "$changes" -gt 0 ]]; then
        if [[ "$approvals" -gt 0 ]]; then
            printf 'mixed\n'
        else
            printf 'request-changes\n'
        fi
    elif [[ "$approvals" -eq "$total" ]]; then
        printf 'approve\n'
    elif [[ "$comments" -eq "$total" ]]; then
        printf 'comment\n'
    else
        printf 'mixed\n'
    fi
}

# ══════════════════════════════════════════════════
# v0.3 Individual Findings with Severity
# ══════════════════════════════════════════════════

# orch_review_record_finding <severity> <reviewer_id> <target_id> <description>
#   Record a single finding with severity classification.
#   severity: critical | major | minor | suggestion | note
orch_review_record_finding() {
    local severity="${1:?record_finding: severity required}"
    local reviewer="${2:?record_finding: reviewer required}"
    local target="${3:?record_finding: target required}"
    local description="${4:?record_finding: description required}"

    # Validate severity
    local valid=false
    local s
    for s in "${_ORCH_REVIEW_SEVERITIES[@]}"; do
        [[ "$s" == "$severity" ]] && valid=true
    done
    [[ "$valid" == false ]] && {
        _orch_review_log WARN "Invalid severity: $severity"
        return 1
    }

    _ORCH_REVIEW_FINDING_LIST+=("${severity}|${reviewer}|${target}|${description}")
    return 0
}

# orch_review_findings_by_severity [target_id]
#   Print findings grouped by severity. If target_id given, filter to that target.
orch_review_findings_by_severity() {
    local filter_target="${1:-}"

    for sev in "${_ORCH_REVIEW_SEVERITIES[@]}"; do
        local has_findings=false
        local finding
        for finding in "${_ORCH_REVIEW_FINDING_LIST[@]+"${_ORCH_REVIEW_FINDING_LIST[@]}"}"; do
            IFS='|' read -r f_sev f_rev f_target f_desc <<< "$finding"
            [[ "$f_sev" != "$sev" ]] && continue
            [[ -n "$filter_target" && "$f_target" != "$filter_target" ]] && continue

            if [[ "$has_findings" == false ]]; then
                printf '### %s\n' "${sev^^}"
                has_findings=true
            fi
            printf '%s\n' "- [${sev^^}] $f_desc (reviewer: $f_rev, target: $f_target)"
        done
        if [[ "$has_findings" == true ]]; then printf '\n'; fi
    done
}

# orch_review_finding_count [severity] [target_id]
#   Count findings matching severity and/or target. Both optional filters.
orch_review_finding_count() {
    local filter_sev="${1:-}"
    local filter_target="${2:-}"
    local count=0

    local finding
    for finding in "${_ORCH_REVIEW_FINDING_LIST[@]+"${_ORCH_REVIEW_FINDING_LIST[@]}"}"; do
        IFS='|' read -r f_sev f_rev f_target f_desc <<< "$finding"
        [[ -n "$filter_sev" && "$f_sev" != "$filter_sev" ]] && continue
        [[ -n "$filter_target" && "$f_target" != "$filter_target" ]] && continue
        count=$((count + 1))
    done

    printf '%d\n' "$count"
}

# orch_review_feedback_template <target_id>
#   Generate a structured, actionable feedback template combining
#   verdicts, rubric scores, and findings for PM consumption.
orch_review_feedback_template() {
    local target="${1:?feedback_template: target required}"

    printf '# Review Feedback: %s — Cycle %s\n\n' "$target" "$_ORCH_REVIEW_CYCLE"

    # Consensus
    local consensus
    consensus=$(orch_review_consensus "$target")
    printf '**Consensus:** %s\n\n' "$consensus"

    # Verdicts by reviewer
    printf '## Reviewer Verdicts\n'
    for key in "${!_ORCH_REVIEW_VERDICTS[@]}"; do
        if [[ "$key" == *"|${target}" ]]; then
            local reviewer="${key%%|*}"
            printf '%s\n' "- **${reviewer}:** ${_ORCH_REVIEW_VERDICTS[$key]}"
        fi
    done
    printf '\n'

    # Findings by severity
    printf '## Findings\n'
    orch_review_findings_by_severity "$target"

    # Action items summary
    local critical_count major_count
    critical_count=$(orch_review_finding_count "critical" "$target")
    major_count=$(orch_review_finding_count "major" "$target")

    printf '## Required Actions\n'
    if [[ "$critical_count" -gt 0 ]]; then
        printf '**BLOCKING:** %d critical finding(s) must be resolved before merge.\n' "$critical_count"
    fi
    if [[ "$major_count" -gt 0 ]]; then
        printf '**RECOMMENDED:** %d major finding(s) should be addressed.\n' "$major_count"
    fi
    if [[ "$critical_count" -eq 0 && "$major_count" -eq 0 ]]; then
        printf 'No blocking or major issues found.\n'
    fi
}
