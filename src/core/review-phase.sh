#!/usr/bin/env bash
# =============================================================================
# review-phase.sh — Loop review & critique system (#24)
#
# After agents execute and commit, selected reviewer agents critique the diffs.
# Reviews are read-only markdown critiques — reviewers cannot modify code.
#
# The 6th column "reviews" in agents.conf lists comma-separated agent IDs that
# each agent reviews, or "none" to skip. Reviewer receives the git diff of the
# reviewed agent's commit, the reviewed agent's prompt, and a review template.
# Output is written to prompts/<reviewer>/reviews/cycle-<N>-<target>.md.
#
# Usage:
#   source src/core/review-phase.sh
#
#   orch_review_init 5 "/path/to/project"
#   orch_review_parse_config "agents.conf"
#   orch_review_assign "09-qa" "06-backend,11-web"
#   orch_review_get_assignments "09-qa"        # → "06-backend,11-web"
#   orch_review_get_reviewers "06-backend"     # → "09-qa"
#   orch_review_should_run "06-backend"
#   diff=$(orch_review_generate_diff "06-backend" "abc1234")
#   prompt=$(orch_review_build_prompt "09-qa" "06-backend" "$diff" "prompts/06-backend/06-backend.txt")
#   orch_review_save "09-qa" "06-backend" "$review_content"
#   orch_review_has_blocking "09-qa"
#   orch_review_summary
#   orch_review_report
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_REVIEW_PHASE_LOADED:-}" ]] && return 0
readonly _ORCH_REVIEW_PHASE_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -gA _ORCH_REVIEW_ASSIGNMENTS=()    # reviewer_id → "target1,target2"
declare -gA _ORCH_REVIEW_RESULTS=()        # "reviewer:target" → "approve" | "request-changes" | "comment"
declare -g  _ORCH_REVIEW_CYCLE=0
declare -g  _ORCH_REVIEW_ROOT=""
declare -ga _ORCH_REVIEW_REVIEWERS=()      # list of reviewer agent IDs

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _orch_review_trim <string>
#   Strip leading and trailing whitespace; print the result.
_orch_review_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# _orch_review_log <message>
#   Print a timestamped log line to stderr.
_orch_review_log() {
    printf '[review-phase] %s\n' "$1" >&2
}

# _orch_review_err <message>
#   Print an error message to stderr.
_orch_review_err() {
    printf '[review-phase] ERROR: %s\n' "$1" >&2
}

# ---------------------------------------------------------------------------
# orch_review_init — Initialize for a cycle
#
# Args:
#   $1 — current cycle number (required)
#   $2 — project root (optional, defaults to git rev-parse --show-toplevel)
# ---------------------------------------------------------------------------
orch_review_init() {
    _ORCH_REVIEW_CYCLE="${1:?orch_review_init requires a cycle number}"
    _ORCH_REVIEW_ROOT="${2:-}"

    # Reset state
    _ORCH_REVIEW_ASSIGNMENTS=()
    _ORCH_REVIEW_RESULTS=()
    _ORCH_REVIEW_REVIEWERS=()

    # Resolve project root if not provided
    if [[ -z "$_ORCH_REVIEW_ROOT" ]]; then
        _ORCH_REVIEW_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    fi
}

# ---------------------------------------------------------------------------
# orch_review_parse_config — Parse agents.conf for review assignments
#
# Reads the config file and looks for a 7th pipe-delimited column (index 6)
# containing comma-separated agent IDs that this agent reviews.
# Lines with "none" or missing column are skipped.
#
# Args:
#   $1 — path to agents.conf (required)
# ---------------------------------------------------------------------------
orch_review_parse_config() {
    local conf_file="${1:?orch_review_parse_config requires a config file path}"

    if [[ ! -f "$conf_file" ]]; then
        _orch_review_err "config file not found: $conf_file"
        return 1
    fi

    local line
    while IFS= read -r line; do
        # Skip blank lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Split by pipe delimiter
        local -a fields=()
        IFS='|' read -ra fields <<< "$line"

        # Need at least 7 columns to have the reviews column
        [[ ${#fields[@]} -lt 7 ]] && continue

        local agent_id
        agent_id=$(_orch_review_trim "${fields[0]}")
        local reviews_col
        reviews_col=$(_orch_review_trim "${fields[6]}")

        # Skip "none" or empty
        [[ -z "$reviews_col" || "$reviews_col" == "none" ]] && continue

        # Store the assignment
        _ORCH_REVIEW_ASSIGNMENTS["$agent_id"]="$reviews_col"

        # Track this agent as a reviewer
        local -i found=0
        local existing
        for existing in "${_ORCH_REVIEW_REVIEWERS[@]}"; do
            [[ "$existing" == "$agent_id" ]] && { found=1; break; }
        done
        [[ $found -eq 0 ]] && _ORCH_REVIEW_REVIEWERS+=("$agent_id")

    done < "$conf_file"
}

# ---------------------------------------------------------------------------
# orch_review_assign — Manually assign review targets
#
# Args:
#   $1 — reviewer agent ID (required)
#   $2 — comma-separated target agent IDs (required)
# ---------------------------------------------------------------------------
orch_review_assign() {
    local reviewer_id="${1:?orch_review_assign requires a reviewer ID}"
    local target_ids="${2:?orch_review_assign requires target IDs}"

    _ORCH_REVIEW_ASSIGNMENTS["$reviewer_id"]="$target_ids"

    # Add to reviewers list if not already present
    local -i found=0
    local existing
    for existing in "${_ORCH_REVIEW_REVIEWERS[@]}"; do
        [[ "$existing" == "$reviewer_id" ]] && { found=1; break; }
    done
    [[ $found -eq 0 ]] && _ORCH_REVIEW_REVIEWERS+=("$reviewer_id")
}

# ---------------------------------------------------------------------------
# orch_review_get_assignments — Return comma-separated review targets
#
# Args:
#   $1 — reviewer agent ID
#
# Outputs: comma-separated target IDs, or empty string
# ---------------------------------------------------------------------------
orch_review_get_assignments() {
    local reviewer_id="${1:?orch_review_get_assignments requires a reviewer ID}"
    echo "${_ORCH_REVIEW_ASSIGNMENTS[$reviewer_id]:-}"
}

# ---------------------------------------------------------------------------
# orch_review_get_reviewers — Return list of agents that review a target
#
# Args:
#   $1 — target agent ID
#
# Outputs: space-separated reviewer IDs
# ---------------------------------------------------------------------------
orch_review_get_reviewers() {
    local target_id="${1:?orch_review_get_reviewers requires a target ID}"
    local -a reviewers=()

    local reviewer_id
    for reviewer_id in "${!_ORCH_REVIEW_ASSIGNMENTS[@]}"; do
        local targets="${_ORCH_REVIEW_ASSIGNMENTS[$reviewer_id]}"
        # Split targets by comma and check for match
        local -a target_list=()
        IFS=',' read -ra target_list <<< "$targets"
        local t
        for t in "${target_list[@]}"; do
            t=$(_orch_review_trim "$t")
            if [[ "$t" == "$target_id" ]]; then
                reviewers+=("$reviewer_id")
                break
            fi
        done
    done

    echo "${reviewers[*]}"
}

# ---------------------------------------------------------------------------
# orch_review_generate_diff — Generate git diff for a reviewed agent
#
# Produces the diff of commits made by the target agent since a given ref.
# Filters output to only include files within the agent's ownership paths
# (looked up from agents.conf via the prompt directory convention).
#
# Args:
#   $1 — agent_id (used to scope diff to agent's prompt directory)
#   $2 — since_ref (git ref, e.g., commit hash before agent ran)
#
# Outputs: diff text via stdout
# ---------------------------------------------------------------------------
orch_review_generate_diff() {
    local agent_id="${1:?orch_review_generate_diff requires an agent ID}"
    local since_ref="${2:?orch_review_generate_diff requires a since_ref}"

    if [[ -z "$_ORCH_REVIEW_ROOT" ]]; then
        _orch_review_err "review phase not initialized (call orch_review_init first)"
        return 1
    fi

    # Generate the full diff since the reference commit
    # The agent's prompt directory always lives under prompts/<agent_id>/
    # We include all files — the caller or orchestrator already scoped commits
    local diff_output
    diff_output=$(git -C "$_ORCH_REVIEW_ROOT" diff "${since_ref}..HEAD" 2>/dev/null)

    if [[ -z "$diff_output" ]]; then
        echo "# No diff found for ${agent_id} since ${since_ref}"
        return 0
    fi

    # Filter diff to only show files relevant to this agent's ownership.
    # Convention: agent's files include prompts/<agent_id>/ and the paths
    # listed in agents.conf ownership column.  For a lightweight approach,
    # we use git diff with pathspecs derived from the agent ID prefix.
    # Callers who need tighter ownership filtering can pre-compute paths.
    local filtered_diff
    filtered_diff=$(git -C "$_ORCH_REVIEW_ROOT" diff "${since_ref}..HEAD" \
        -- "prompts/${agent_id}/" 2>/dev/null)

    # Also include ownership paths if the agent has them configured.
    # Fall back to the full diff if the filtered version is empty (agent
    # may own paths outside prompts/).
    if [[ -n "$filtered_diff" ]]; then
        echo "$filtered_diff"
    else
        echo "$diff_output"
    fi
}

# ---------------------------------------------------------------------------
# orch_review_build_prompt — Build the review prompt for a reviewer
#
# Returns a formatted prompt string containing the review template,
# the diff being reviewed, context from the target agent's prompt,
# and instructions to output structured markdown.
#
# Args:
#   $1 — reviewer_id
#   $2 — target_id
#   $3 — diff_text
#   $4 — target_prompt_path (path to the target agent's prompt file)
#
# Outputs: formatted review prompt via stdout
# ---------------------------------------------------------------------------
orch_review_build_prompt() {
    local reviewer_id="${1:?orch_review_build_prompt requires a reviewer ID}"
    local target_id="${2:?orch_review_build_prompt requires a target ID}"
    local diff_text="${3:-}"
    local target_prompt_path="${4:-}"
    local cycle="$_ORCH_REVIEW_CYCLE"

    # Extract first 50 lines of the target agent's prompt for context
    local target_context="(no prompt available)"
    if [[ -n "$target_prompt_path" && -f "$target_prompt_path" ]]; then
        target_context=$(head -n 50 "$target_prompt_path" 2>/dev/null || echo "(could not read prompt)")
    fi

    # Handle empty diff
    if [[ -z "$diff_text" ]]; then
        diff_text="(no changes detected)"
    fi

    # Build the review prompt using the embedded template
    cat <<REVIEW_TEMPLATE
## Review: ${target_id} — Cycle ${cycle}

You are reviewing the diff below from agent ${target_id}.
You are reviewer ${reviewer_id}. This is a read-only review — do NOT modify any code.

### Diff
\`\`\`diff
${diff_text}
\`\`\`

### Target Agent Context (first 50 lines of prompt)
${target_context}

### Instructions
Review the diff for:
1. Correctness — does the code do what it claims?
2. Style — does it follow project conventions?
3. Security — any injection, eval, or unsafe patterns?
4. Conflicts — does it conflict with other agents' work?

### Your Verdict
Choose ONE: **approve**, **request-changes**, or **comment**

Format your response as markdown with exactly this structure:

\`\`\`
**Verdict:** [approve|request-changes|comment]

**Summary:** [one-line summary]

**Details:**
[your detailed review notes]
\`\`\`
REVIEW_TEMPLATE
}

# ---------------------------------------------------------------------------
# orch_review_save — Save review output to the reviewer's reviews directory
#
# Path: prompts/<reviewer>/reviews/cycle-<N>-<target>.md
# Creates the reviews/ directory if needed.
# Prepends a header with timestamp, reviewer, target.
#
# Args:
#   $1 — reviewer_id
#   $2 — target_id
#   $3 — review_content (the raw review output from the reviewer agent)
# ---------------------------------------------------------------------------
orch_review_save() {
    local reviewer_id="${1:?orch_review_save requires a reviewer ID}"
    local target_id="${2:?orch_review_save requires a target ID}"
    local review_content="${3:-}"

    local reviews_dir="${_ORCH_REVIEW_ROOT}/prompts/${reviewer_id}/reviews"
    local review_file="${reviews_dir}/cycle-${_ORCH_REVIEW_CYCLE}-${target_id}.md"

    # Create reviews directory if needed
    if [[ ! -d "$reviews_dir" ]]; then
        mkdir -p "$reviews_dir" || {
            _orch_review_err "could not create reviews directory: $reviews_dir"
            return 1
        }
    fi

    # Write the review with a metadata header
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')

    {
        printf '---\n'
        printf 'reviewer: %s\n' "$reviewer_id"
        printf 'target: %s\n' "$target_id"
        printf 'cycle: %s\n' "$_ORCH_REVIEW_CYCLE"
        printf 'timestamp: %s\n' "$now"
        printf '---\n\n'
        printf '%s\n' "$review_content"
    } > "$review_file" || {
        _orch_review_err "could not write review file: $review_file"
        return 1
    }

    # Parse verdict from the review content and store in results
    local verdict="comment"
    if echo "$review_content" | grep -qi 'request-changes'; then
        verdict="request-changes"
    elif echo "$review_content" | grep -qi '\*\*Verdict:\*\*.*approve'; then
        verdict="approve"
    elif echo "$review_content" | grep -qi 'approve'; then
        verdict="approve"
    fi

    _ORCH_REVIEW_RESULTS["${reviewer_id}:${target_id}"]="$verdict"

    _orch_review_log "saved review: ${reviewer_id} → ${target_id} [${verdict}] → ${review_file}"
}

# ---------------------------------------------------------------------------
# orch_review_has_blocking — Check if any review from this reviewer blocks
#
# Returns 0 if blocking issues found (request-changes), 1 if all clear.
#
# Args:
#   $1 — reviewer_id
# ---------------------------------------------------------------------------
orch_review_has_blocking() {
    local reviewer_id="${1:?orch_review_has_blocking requires a reviewer ID}"

    local key
    for key in "${!_ORCH_REVIEW_RESULTS[@]}"; do
        # Keys are "reviewer:target" — match on reviewer prefix
        if [[ "$key" == "${reviewer_id}:"* ]]; then
            if [[ "${_ORCH_REVIEW_RESULTS[$key]}" == "request-changes" ]]; then
                return 0
            fi
        fi
    done

    return 1
}

# ---------------------------------------------------------------------------
# orch_review_summary — Aggregate all reviews for the cycle
#
# Outputs per-target summary showing approve/request-changes/comment counts.
# ---------------------------------------------------------------------------
orch_review_summary() {
    # Collect unique targets from results
    local -A target_approve=()
    local -A target_request=()
    local -A target_comment=()
    local -A targets_seen=()

    local key
    for key in "${!_ORCH_REVIEW_RESULTS[@]}"; do
        local verdict="${_ORCH_REVIEW_RESULTS[$key]}"
        # Extract target from "reviewer:target" key
        local target="${key#*:}"
        targets_seen["$target"]=1

        case "$verdict" in
            approve)
                target_approve["$target"]=$(( ${target_approve[$target]:-0} + 1 ))
                ;;
            request-changes)
                target_request["$target"]=$(( ${target_request[$target]:-0} + 1 ))
                ;;
            comment|*)
                target_comment["$target"]=$(( ${target_comment[$target]:-0} + 1 ))
                ;;
        esac
    done

    if [[ ${#targets_seen[@]} -eq 0 ]]; then
        echo "No reviews recorded for cycle ${_ORCH_REVIEW_CYCLE}."
        return 0
    fi

    echo "Review Summary — Cycle ${_ORCH_REVIEW_CYCLE}"
    echo "================================================"

    local target
    for target in $(echo "${!targets_seen[@]}" | tr ' ' '\n' | sort); do
        local approves="${target_approve[$target]:-0}"
        local requests="${target_request[$target]:-0}"
        local comments="${target_comment[$target]:-0}"
        local status="OK"
        [[ $requests -gt 0 ]] && status="BLOCKED"

        printf '  %-20s approve=%d  request-changes=%d  comment=%d  [%s]\n' \
            "$target" "$approves" "$requests" "$comments" "$status"
    done
}

# ---------------------------------------------------------------------------
# orch_review_should_run — Check if a target agent produced commits this cycle
#
# Uses the cycle start marker to determine if the target has new commits.
# Returns 0 if the target has new commits (worth reviewing), 1 otherwise.
#
# Args:
#   $1 — target agent ID
# ---------------------------------------------------------------------------
orch_review_should_run() {
    local target_id="${1:?orch_review_should_run requires a target ID}"

    if [[ -z "$_ORCH_REVIEW_ROOT" ]]; then
        _orch_review_err "review phase not initialized (call orch_review_init first)"
        return 1
    fi

    # Check if there are recent commits mentioning this agent ID in the
    # commit message (convention: agent commits include the agent ID).
    # We look at the last 20 commits on the current branch.
    local commit_count
    commit_count=$(git -C "$_ORCH_REVIEW_ROOT" log --oneline -20 \
        --grep="$target_id" 2>/dev/null | wc -l)

    if [[ $commit_count -gt 0 ]]; then
        return 0
    fi

    # Fallback: check for any recent changes in the agent's prompt directory
    local agent_prompt_dir="${_ORCH_REVIEW_ROOT}/prompts/${target_id}"
    if [[ -d "$agent_prompt_dir" ]]; then
        local changed_files
        changed_files=$(git -C "$_ORCH_REVIEW_ROOT" diff --name-only HEAD~1 -- \
            "prompts/${target_id}/" 2>/dev/null | wc -l)
        [[ $changed_files -gt 0 ]] && return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# orch_review_checklist — Generate a structured pass/fail checklist prompt
#
# Instead of an open-ended freeform review, this produces a prompt that asks
# the reviewer to tick off concrete pass/fail items.  This eliminates debate
# loops by giving reviewers a deterministic checklist rather than an open
# question.
#
# Args:
#   $1 — reviewer_id
#   $2 — target_id
#   $3 — diff_text
#   $4 — review_type  (one of: "security", "correctness", "style", "full")
#
# Outputs: formatted checklist prompt via stdout
# ---------------------------------------------------------------------------
orch_review_checklist() {
    local reviewer_id="${1:?orch_review_checklist requires a reviewer ID}"
    local target_id="${2:?orch_review_checklist requires a target ID}"
    local diff_text="${3:-}"
    local review_type="${4:-full}"
    local cycle="$_ORCH_REVIEW_CYCLE"

    # Handle empty diff
    if [[ -z "$diff_text" ]]; then
        diff_text="(no changes detected)"
    fi

    # Validate review_type
    case "$review_type" in
        security|correctness|style|full) ;;
        *)
            _orch_review_err "orch_review_checklist: unknown review_type '$review_type' (use security|correctness|style|full)"
            return 1
            ;;
    esac

    _orch_review_log "building checklist: ${reviewer_id} → ${target_id} [${review_type}]"

    # Build the header block
    cat <<CHECKLIST_HEADER
## Checklist Review: ${target_id} — Cycle ${cycle}

You are reviewer **${reviewer_id}** performing a structured checklist review of
agent **${target_id}**'s diff.  For each item below, mark it **PASS** or **FAIL**
followed by a one-line note.  Do NOT write free-form prose — stick to the
checklist format.  This is a read-only review; do NOT modify any code.

### Diff
\`\`\`diff
${diff_text}
\`\`\`

CHECKLIST_HEADER

    # Security checklist
    if [[ "$review_type" == "security" || "$review_type" == "full" ]]; then
        cat <<SECURITY_CHECKLIST
### Security Checklist
- [ ] **INJ-1** No shell-injection risk (variables properly quoted in \`eval\`/\`exec\`/subshells)
- [ ] **INJ-2** No \`eval\` or \`source\` of untrusted/user-supplied input
- [ ] **VAR-1** All variables are quoted where used in command contexts
- [ ] **PATH-1** No path-traversal risk (no unvalidated \`../\` in user-facing inputs)
- [ ] **DATA-1** No hardcoded secrets, tokens, or passwords introduced

SECURITY_CHECKLIST
    fi

    # Correctness checklist
    if [[ "$review_type" == "correctness" || "$review_type" == "full" ]]; then
        cat <<CORRECTNESS_CHECKLIST
### Correctness Checklist
- [ ] **ERR-1** All commands check return codes or use \`set -e\` / \`|| return 1\` guards
- [ ] **EDGE-1** Empty/missing arguments are handled (not silently ignored)
- [ ] **RET-1** Functions return a meaningful exit code (0=success, non-zero=failure)
- [ ] **ARG-1** Required arguments are validated with \`:?\` or explicit guards
- [ ] **EDGE-2** Edge cases for zero-length inputs are covered

CORRECTNESS_CHECKLIST
    fi

    # Style checklist
    if [[ "$review_type" == "style" || "$review_type" == "full" ]]; then
        cat <<STYLE_CHECKLIST
### Style Checklist
- [ ] **NAME-1** Variable and function names follow existing project conventions
- [ ] **CMT-1** All new functions have a header comment block (name, args, output)
- [ ] **FUNC-1** Functions are single-purpose and under ~50 lines
- [ ] **SC-1** Code would pass \`shellcheck\` without warnings (SC2034, SC2086, etc.)

STYLE_CHECKLIST
    fi

    # Verdict instructions
    cat <<CHECKLIST_FOOTER
### Verdict
After completing the checklist, output ONE of: **approve**, **request-changes**, or **comment**

Format:
\`\`\`
**Verdict:** [approve|request-changes|comment]
**Failed items:** [comma-separated item IDs, or "none"]
**Summary:** [one sentence]
\`\`\`
CHECKLIST_FOOTER
}

# ---------------------------------------------------------------------------
# orch_review_batch — Review multiple targets in a single combined prompt pass
#
# Rather than generating N separate review prompts (which requires N separate
# agent invocations and round-trips), this function concatenates all diffs into
# one prompt.  This is more token-efficient and eliminates back-and-forth when
# the same reviewer covers many agents in one cycle.
#
# Args:
#   $1 — reviewer_id
#   $2 — comma-separated target_ids
#   $3 — since_ref (git ref; passed to orch_review_generate_diff for each target)
#
# Outputs: single combined review prompt via stdout
# ---------------------------------------------------------------------------
orch_review_batch() {
    local reviewer_id="${1:?orch_review_batch requires a reviewer ID}"
    local target_ids="${2:?orch_review_batch requires target IDs}"
    local since_ref="${3:?orch_review_batch requires a since_ref}"
    local cycle="$_ORCH_REVIEW_CYCLE"

    if [[ -z "$_ORCH_REVIEW_ROOT" ]]; then
        _orch_review_err "review phase not initialized (call orch_review_init first)"
        return 1
    fi

    _orch_review_log "batch review: ${reviewer_id} covering [${target_ids}] since ${since_ref}"

    # Header
    cat <<BATCH_HEADER
## Batch Review — Reviewer: ${reviewer_id} — Cycle ${cycle}

You are reviewer **${reviewer_id}**.  Below are the diffs from multiple agents
since ref \`${since_ref}\`.  Review ALL agents in a single pass.  For each agent,
provide a verdict block.  Do NOT review them separately; complete the entire
batch before outputting any results.

BATCH_HEADER

    # Iterate over comma-separated target list
    local -a target_list=()
    IFS=',' read -ra target_list <<< "$target_ids"
    local t
    for t in "${target_list[@]}"; do
        t=$(_orch_review_trim "$t")
        [[ -z "$t" ]] && continue

        local diff_text
        diff_text=$(orch_review_generate_diff "$t" "$since_ref" 2>/dev/null || echo "(diff unavailable)")

        if [[ -z "$diff_text" ]]; then
            diff_text="(no changes detected)"
        fi

        cat <<BATCH_SECTION
### Agent: ${t}
\`\`\`diff
${diff_text}
\`\`\`

BATCH_SECTION
    done

    # Batch verdict instructions
    cat <<BATCH_FOOTER
### Verdicts (one per agent)
For each agent listed above, output a verdict block in this exact format:

\`\`\`
**Agent:** [agent_id]
**Verdict:** [approve|request-changes|comment]
**Summary:** [one sentence]
\`\`\`

Repeat the block for every agent.  Do NOT skip any.
BATCH_FOOTER
}

# ---------------------------------------------------------------------------
# orch_review_prioritize — Sort agents by review priority
#
# Agents with the most changed lines are reviewed first.  Among agents with
# equal line counts, those that touched security-relevant files (src/core/,
# scripts/, *.sh, src-tauri/src/) are elevated.  Agents with zero changes
# are omitted entirely — no point running a review against an empty diff.
#
# Args:
#   $1 — comma-separated agent_ids to evaluate
#   $2 — since_ref (git ref used to measure diff size)
#
# Outputs: newline-separated agent IDs in priority order (highest first)
#          skips agents with zero diff lines
# ---------------------------------------------------------------------------
orch_review_prioritize() {
    local agent_ids="${1:?orch_review_prioritize requires agent IDs}"
    local since_ref="${2:?orch_review_prioritize requires a since_ref}"

    if [[ -z "$_ORCH_REVIEW_ROOT" ]]; then
        _orch_review_err "review phase not initialized (call orch_review_init first)"
        return 1
    fi

    # Security-relevant path patterns (grep-compatible basic regex)
    local -a sec_patterns=("src/core/" "scripts/" "\.sh$" "src-tauri/src/")

    # Collect "score agent_id" pairs: score = lines_changed * 10 + security_bonus
    local -a scored=()
    local -a agent_list=()
    IFS=',' read -ra agent_list <<< "$agent_ids"

    local agent_id
    for agent_id in "${agent_list[@]}"; do
        agent_id=$(_orch_review_trim "$agent_id")
        [[ -z "$agent_id" ]] && continue

        # Count lines changed for this agent
        # Use only the agent-scoped diff (prompts/<agent_id>/ path).
        # We do NOT use orch_review_generate_diff here because its fallback to
        # the full repo diff would give nonexistent agents a non-zero line count.
        local diff_text
        diff_text=$(git -C "$_ORCH_REVIEW_ROOT" diff "${since_ref}..HEAD" \
            -- "prompts/${agent_id}/" 2>/dev/null || true)

        local line_count=0
        if [[ -n "$diff_text" ]]; then
            line_count=$(printf '%s' "$diff_text" | wc -l)
        fi

        # Skip agents with zero changes in their own paths
        [[ $line_count -eq 0 ]] && {
            _orch_review_log "prioritize: skipping ${agent_id} (zero diff lines)"
            continue
        }

        # Security bonus: +1000 if diff touches any security-relevant path
        local sec_bonus=0
        local pat
        for pat in "${sec_patterns[@]}"; do
            if printf '%s' "$diff_text" | grep -q "$pat" 2>/dev/null; then
                sec_bonus=1000
                break
            fi
        done

        local score=$(( line_count + sec_bonus ))
        scored+=("${score} ${agent_id}")
    done

    # Sort by score descending and output agent IDs only
    if [[ ${#scored[@]} -gt 0 ]]; then
        printf '%s\n' "${scored[@]}" | sort -rn | awk '{print $2}'
    fi
}

# ---------------------------------------------------------------------------
# orch_review_auto_verdict — Auto-approve trivially small/safe changes
#
# If the diff is under a configurable line threshold AND only touches low-risk
# directories (prompts/ or docs/), there is no value in spending an agent
# review cycle on it.  This function short-circuits the review and records an
# automatic approval so the orchestrator can move on.
#
# Args:
#   $1 — agent_id
#   $2 — since_ref
#   $3 — threshold  (optional; default 5 — number of diff lines)
#
# Returns:
#   0 — auto-approved (trivial change; no human/agent review needed)
#   1 — not auto-approved (change requires a proper review)
# ---------------------------------------------------------------------------
orch_review_auto_verdict() {
    local agent_id="${1:?orch_review_auto_verdict requires an agent ID}"
    local since_ref="${2:?orch_review_auto_verdict requires a since_ref}"
    local threshold="${3:-5}"

    if [[ -z "$_ORCH_REVIEW_ROOT" ]]; then
        _orch_review_err "review phase not initialized (call orch_review_init first)"
        return 1
    fi

    local diff_text
    diff_text=$(orch_review_generate_diff "$agent_id" "$since_ref" 2>/dev/null || true)

    # Count meaningful diff lines (+ and - only, not headers)
    local line_count=0
    if [[ -n "$diff_text" ]]; then
        line_count=$(printf '%s' "$diff_text" | grep -c '^[+-]' 2>/dev/null || true)
    fi

    # Condition 1: diff must be under threshold
    if [[ $line_count -ge $threshold ]]; then
        _orch_review_log "auto_verdict: ${agent_id} not auto-approved (${line_count} lines >= threshold ${threshold})"
        return 1
    fi

    # Condition 2: all changed files must be in prompts/ or docs/ only
    local changed_files
    changed_files=$(git -C "$_ORCH_REVIEW_ROOT" diff --name-only "${since_ref}..HEAD" 2>/dev/null || true)

    if [[ -n "$changed_files" ]]; then
        # Check if any file is outside prompts/ and docs/
        local unsafe_file
        unsafe_file=$(printf '%s\n' "$changed_files" | grep -v '^prompts/' | grep -v '^docs/' || true)
        if [[ -n "$unsafe_file" ]]; then
            _orch_review_log "auto_verdict: ${agent_id} not auto-approved (files outside prompts/ or docs/)"
            return 1
        fi
    fi

    # All conditions met — record automatic approval
    _ORCH_REVIEW_RESULTS["auto:${agent_id}"]="approve"
    _orch_review_log "auto_verdict: ${agent_id} AUTO-APPROVED (${line_count} lines, safe paths only)"
    return 0
}

# ---------------------------------------------------------------------------
# orch_review_report — Print formatted report of all reviews
# ---------------------------------------------------------------------------
orch_review_report() {
    echo "Review Phase Report — Cycle ${_ORCH_REVIEW_CYCLE}"
    echo "========================================================"
    echo ""

    # List all reviewers and their assignments
    if [[ ${#_ORCH_REVIEW_REVIEWERS[@]} -eq 0 ]]; then
        echo "  No reviewers configured for this cycle."
        echo ""
        return 0
    fi

    echo "Reviewers:"
    local reviewer_id
    for reviewer_id in $(printf '%s\n' "${_ORCH_REVIEW_REVIEWERS[@]}" | sort); do
        local targets="${_ORCH_REVIEW_ASSIGNMENTS[$reviewer_id]:-none}"
        printf '  %-20s reviews: %s\n' "$reviewer_id" "$targets"
    done
    echo ""

    # List all recorded results
    if [[ ${#_ORCH_REVIEW_RESULTS[@]} -eq 0 ]]; then
        echo "Results: (no reviews completed)"
        echo ""
    else
        echo "Results:"
        local key
        for key in $(echo "${!_ORCH_REVIEW_RESULTS[@]}" | tr ' ' '\n' | sort); do
            local verdict="${_ORCH_REVIEW_RESULTS[$key]}"
            local reviewer="${key%%:*}"
            local target="${key#*:}"
            local marker="  "
            case "$verdict" in
                approve)          marker="OK" ;;
                request-changes)  marker="!!" ;;
                comment)          marker="--" ;;
            esac
            printf '  [%s] %-15s → %-15s  %s\n' "$marker" "$reviewer" "$target" "$verdict"
        done
        echo ""
    fi

    # Print summary
    orch_review_summary
    echo ""

    # Check for blocking reviews
    local -i has_any_blocking=0
    for reviewer_id in "${_ORCH_REVIEW_REVIEWERS[@]}"; do
        if orch_review_has_blocking "$reviewer_id"; then
            has_any_blocking=1
            echo "  WARNING: ${reviewer_id} has blocking review(s) (request-changes)"
        fi
    done

    if [[ $has_any_blocking -eq 0 && ${#_ORCH_REVIEW_RESULTS[@]} -gt 0 ]]; then
        echo "  All reviews passed — no blocking issues."
    fi
}
