#!/usr/bin/env bash
# =============================================================================
# init-project.sh — Project analyzer & agent blueprint generator (#45)
#
# Scans a target project directory to detect languages, frameworks, package
# managers, test frameworks, and CI/CD config. Generates a suggested
# agents.conf and scaffold prompt files based on what was found.
#
# v0.4.0 additions:
#   - Interactive mode (orch_init_interactive) — guided setup wizard
#   - Template marketplace (orch_init_list_templates / orch_init_apply_template)
#   - Auto-detect existing OrchyStraw structure (orch_init_detect_existing)
#   - Migration support (orch_init_migrate) — upgrade v0.2→v0.3→v0.4 configs
#
# Usage:
#   source src/core/init-project.sh
#
#   orch_init_scan "/path/to/project"
#   orch_init_report
#   orch_init_generate_conf  "/path/to/output/agents.conf"
#   orch_init_generate_prompts "/path/to/output/prompts"
#
#   # v0.4 features:
#   orch_init_interactive "/path/to/project"     # guided wizard
#   orch_init_detect_existing "/path/to/project"  # check for existing setup
#   orch_init_list_templates                       # available templates
#   orch_init_apply_template "fullstack-saas"      # apply a preset
#   orch_init_migrate "/path/to/project"           # upgrade config format
#
# Requires: bash 5.0+
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_INIT_PROJECT_LOADED:-}" ]] && return 0
readonly _ORCH_INIT_PROJECT_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -g  _ORCH_INIT_PROJECT_DIR=""
declare -g  _ORCH_INIT_SCANNED=0
declare -gA _ORCH_INIT_LANGUAGES=()
declare -gA _ORCH_INIT_FRAMEWORKS=()
declare -gA _ORCH_INIT_PKG_MANAGERS=()
declare -gA _ORCH_INIT_TEST_FRAMEWORKS=()
declare -gA _ORCH_INIT_CI_SYSTEMS=()
declare -g  _ORCH_INIT_HAS_MONOREPO=0
declare -g  _ORCH_INIT_HAS_DOCKER=0
declare -g  _ORCH_INIT_HAS_DATABASE=0
declare -ga _ORCH_INIT_SUGGESTED_AGENTS=()

# Directories to exclude from scanning
readonly _ORCH_INIT_EXCLUDE_DIRS="node_modules .git vendor __pycache__ .venv venv dist build target .next .nuxt"

# v0.4: Template marketplace presets
declare -gA _ORCH_INIT_TEMPLATES=()
declare -g  _ORCH_INIT_EXISTING_VERSION=""
declare -g  _ORCH_INIT_INTERACTIVE_MODE=0

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_orch_init_log() {
    printf '[init-project] %s\n' "$1" >&2
}

_orch_init_err() {
    printf '[init-project] ERROR: %s\n' "$1" >&2
}

_orch_init_reset() {
    _ORCH_INIT_PROJECT_DIR=""
    _ORCH_INIT_SCANNED=0
    _ORCH_INIT_LANGUAGES=()
    _ORCH_INIT_FRAMEWORKS=()
    _ORCH_INIT_PKG_MANAGERS=()
    _ORCH_INIT_TEST_FRAMEWORKS=()
    _ORCH_INIT_CI_SYSTEMS=()
    _ORCH_INIT_HAS_MONOREPO=0
    _ORCH_INIT_HAS_DOCKER=0
    _ORCH_INIT_HAS_DATABASE=0
    _ORCH_INIT_SUGGESTED_AGENTS=()
}

_orch_init_find_files() {
    local project_dir="$1"
    local pattern="$2"

    [[ "$pattern" =~ ^[a-zA-Z0-9.*_-]+$ ]] || return 1

    find "$project_dir" -maxdepth 3 \
        \( -name "node_modules" -o -name ".git" -o -name "vendor" \
           -o -name "__pycache__" -o -name ".venv" -o -name "venv" \
           -o -name "dist" -o -name "build" -o -name "target" \
           -o -name ".next" -o -name ".nuxt" \) -prune \
        -o -name "$pattern" -type f -print 2>/dev/null
}

_orch_init_file_exists() {
    local project_dir="$1"
    local filename="$2"
    local result

    result="$(_orch_init_find_files "$project_dir" "$filename" | head -1)"
    [[ -n "$result" ]]
}

_orch_init_has_ext() {
    local project_dir="$1"
    local ext="$2"
    local result

    result="$(_orch_init_find_files "$project_dir" "*${ext}" | head -1)"
    [[ -n "$result" ]]
}

_orch_init_pkg_json_has_dep() {
    local project_dir="$1"
    local dep_name="$2"
    local pkg_json="${project_dir}/package.json"

    [[ -f "$pkg_json" ]] || return 1
    grep -qF "\"${dep_name}\"" "$pkg_json" 2>/dev/null
}

_orch_init_requirements_has() {
    local project_dir="$1"
    local pkg="$2"

    local req_file
    for req_file in "${project_dir}/requirements.txt" "${project_dir}/requirements-dev.txt" "${project_dir}/requirements_dev.txt"; do
        if [[ -f "$req_file" ]]; then
            grep -qi "^${pkg}" "$req_file" 2>/dev/null && return 0
        fi
    done

    if [[ -f "${project_dir}/pyproject.toml" ]]; then
        grep -qiF "${pkg}" "${project_dir}/pyproject.toml" 2>/dev/null && return 0
    fi
    if [[ -f "${project_dir}/setup.cfg" ]]; then
        grep -qiF "${pkg}" "${project_dir}/setup.cfg" 2>/dev/null && return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Detection functions
# ---------------------------------------------------------------------------

_orch_init_detect_languages() {
    local dir="$1"

    _orch_init_has_ext "$dir" ".sh"  && _ORCH_INIT_LANGUAGES[bash]=1    || true
    _orch_init_has_ext "$dir" ".py"  && _ORCH_INIT_LANGUAGES[python]=1  || true
    _orch_init_has_ext "$dir" ".js"  && _ORCH_INIT_LANGUAGES[javascript]=1  || true
    _orch_init_has_ext "$dir" ".jsx" && _ORCH_INIT_LANGUAGES[javascript]=1  || true
    _orch_init_has_ext "$dir" ".ts"  && _ORCH_INIT_LANGUAGES[typescript]=1  || true
    _orch_init_has_ext "$dir" ".tsx" && _ORCH_INIT_LANGUAGES[typescript]=1  || true

    if _orch_init_has_ext "$dir" ".rs" && [[ -f "${dir}/Cargo.toml" ]]; then
        _ORCH_INIT_LANGUAGES[rust]=1
    fi

    if _orch_init_has_ext "$dir" ".go" && [[ -f "${dir}/go.mod" ]]; then
        _ORCH_INIT_LANGUAGES[go]=1
    fi

    _orch_init_has_ext "$dir" ".swift" && _ORCH_INIT_LANGUAGES[swift]=1  || true
    _orch_init_has_ext "$dir" ".java"  && _ORCH_INIT_LANGUAGES[java]=1   || true
    _orch_init_has_ext "$dir" ".rb"    && _ORCH_INIT_LANGUAGES[ruby]=1   || true
}

_orch_init_detect_frameworks() {
    local dir="$1"

    _orch_init_pkg_json_has_dep "$dir" "react"   && _ORCH_INIT_FRAMEWORKS[react]=1   || true
    _orch_init_pkg_json_has_dep "$dir" "vue"     && _ORCH_INIT_FRAMEWORKS[vue]=1     || true
    _orch_init_pkg_json_has_dep "$dir" "express" && _ORCH_INIT_FRAMEWORKS[express]=1 || true

    _orch_init_file_exists "$dir" "next.config.*"    && _ORCH_INIT_FRAMEWORKS[next]=1    || true
    _orch_init_file_exists "$dir" "vue.config.*"     && _ORCH_INIT_FRAMEWORKS[vue]=1     || true
    _orch_init_file_exists "$dir" "svelte.config.*"  && _ORCH_INIT_FRAMEWORKS[svelte]=1  || true
    _orch_init_file_exists "$dir" "tauri.conf.json"  && _ORCH_INIT_FRAMEWORKS[tauri]=1   || true

    _orch_init_requirements_has "$dir" "django"  && _ORCH_INIT_FRAMEWORKS[django]=1  || true
    _orch_init_requirements_has "$dir" "flask"   && _ORCH_INIT_FRAMEWORKS[flask]=1   || true
    _orch_init_requirements_has "$dir" "fastapi" && _ORCH_INIT_FRAMEWORKS[fastapi]=1 || true

    if _orch_init_file_exists "$dir" "*.xcodeproj" || [[ -f "${dir}/Package.swift" ]]; then
        _ORCH_INIT_FRAMEWORKS[ios]=1
    fi
}

_orch_init_detect_pkg_managers() {
    local dir="$1"

    [[ -f "${dir}/package-lock.json" ]] && _ORCH_INIT_PKG_MANAGERS[npm]=1      || true
    [[ -f "${dir}/yarn.lock" ]]         && _ORCH_INIT_PKG_MANAGERS[yarn]=1     || true
    [[ -f "${dir}/pnpm-lock.yaml" ]]    && _ORCH_INIT_PKG_MANAGERS[pnpm]=1     || true
    { [[ -f "${dir}/requirements.txt" ]] || [[ -f "${dir}/pyproject.toml" ]]; } && _ORCH_INIT_PKG_MANAGERS[pip]=1  || true
    [[ -f "${dir}/Cargo.toml" ]]        && _ORCH_INIT_PKG_MANAGERS[cargo]=1    || true
    [[ -f "${dir}/go.mod" ]]            && _ORCH_INIT_PKG_MANAGERS[go]=1       || true
    [[ -f "${dir}/Podfile" ]]           && _ORCH_INIT_PKG_MANAGERS[cocoapods]=1 || true
    { [[ -f "${dir}/build.gradle" ]] || [[ -f "${dir}/build.gradle.kts" ]]; } && _ORCH_INIT_PKG_MANAGERS[gradle]=1  || true
    [[ -f "${dir}/pom.xml" ]]           && _ORCH_INIT_PKG_MANAGERS[maven]=1    || true

    if [[ -f "${dir}/package.json" ]] && \
       [[ -z "${_ORCH_INIT_PKG_MANAGERS[npm]:-}" ]] && \
       [[ -z "${_ORCH_INIT_PKG_MANAGERS[yarn]:-}" ]] && \
       [[ -z "${_ORCH_INIT_PKG_MANAGERS[pnpm]:-}" ]]; then
        _ORCH_INIT_PKG_MANAGERS[npm]=1
    fi
}

_orch_init_detect_test_frameworks() {
    local dir="$1"

    _orch_init_pkg_json_has_dep "$dir" "jest"   && _ORCH_INIT_TEST_FRAMEWORKS[jest]=1    || true
    _orch_init_pkg_json_has_dep "$dir" "vitest" && _ORCH_INIT_TEST_FRAMEWORKS[vitest]=1  || true
    _orch_init_file_exists "$dir" "jest.config.*"   && _ORCH_INIT_TEST_FRAMEWORKS[jest]=1   || true
    _orch_init_file_exists "$dir" "vitest.config.*"  && _ORCH_INIT_TEST_FRAMEWORKS[vitest]=1 || true

    _orch_init_requirements_has "$dir" "pytest" && _ORCH_INIT_TEST_FRAMEWORKS[pytest]=1  || true
    { [[ -f "${dir}/pytest.ini" ]] || [[ -f "${dir}/conftest.py" ]]; } && _ORCH_INIT_TEST_FRAMEWORKS[pytest]=1  || true

    [[ -n "${_ORCH_INIT_LANGUAGES[rust]:-}" ]] && _ORCH_INIT_TEST_FRAMEWORKS[cargo-test]=1  || true
    [[ -n "${_ORCH_INIT_LANGUAGES[go]:-}" ]] && _ORCH_INIT_TEST_FRAMEWORKS[go-test]=1  || true

    if [[ -n "${_ORCH_INIT_FRAMEWORKS[ios]:-}" ]] || [[ -n "${_ORCH_INIT_LANGUAGES[swift]:-}" ]]; then
        _orch_init_file_exists "$dir" "*Tests.swift" && _ORCH_INIT_TEST_FRAMEWORKS[xctest]=1  || true
    fi
}

_orch_init_detect_ci() {
    local dir="$1"

    [[ -d "${dir}/.github/workflows" ]] && _ORCH_INIT_CI_SYSTEMS[github-actions]=1  || true
    [[ -f "${dir}/.gitlab-ci.yml" ]]    && _ORCH_INIT_CI_SYSTEMS[gitlab-ci]=1      || true
    [[ -f "${dir}/.circleci/config.yml" ]] && _ORCH_INIT_CI_SYSTEMS[circleci]=1    || true
    [[ -f "${dir}/Jenkinsfile" ]]       && _ORCH_INIT_CI_SYSTEMS[jenkins]=1        || true
}

_orch_init_detect_features() {
    local dir="$1"

    if [[ -f "${dir}/lerna.json" ]] || [[ -f "${dir}/turbo.json" ]] || [[ -f "${dir}/pnpm-workspace.yaml" ]]; then
        _ORCH_INIT_HAS_MONOREPO=1
    fi
    if [[ -f "${dir}/package.json" ]]; then
        grep -qF '"workspaces"' "${dir}/package.json" 2>/dev/null && _ORCH_INIT_HAS_MONOREPO=1  || true
    fi
    if [[ -f "${dir}/Cargo.toml" ]]; then
        grep -qF '[workspace]' "${dir}/Cargo.toml" 2>/dev/null && _ORCH_INIT_HAS_MONOREPO=1  || true
    fi

    { [[ -f "${dir}/Dockerfile" ]] || [[ -f "${dir}/docker-compose.yml" ]] || [[ -f "${dir}/docker-compose.yaml" ]]; } && _ORCH_INIT_HAS_DOCKER=1  || true

    if _orch_init_file_exists "$dir" "*.sql" || \
       [[ -d "${dir}/migrations" ]] || [[ -d "${dir}/db" ]] || \
       _orch_init_requirements_has "$dir" "sqlalchemy" || \
       _orch_init_requirements_has "$dir" "prisma" || \
       _orch_init_pkg_json_has_dep "$dir" "prisma" || \
       _orch_init_pkg_json_has_dep "$dir" "knex" || \
       _orch_init_pkg_json_has_dep "$dir" "sequelize" || \
       _orch_init_pkg_json_has_dep "$dir" "typeorm" || \
       [[ -f "${dir}/prisma/schema.prisma" ]]; then
        _ORCH_INIT_HAS_DATABASE=1
    fi
}

_orch_init_is_backend_lang() {
    case "$1" in
        python|rust|go|java|ruby|bash) return 0 ;;
        *) return 1 ;;
    esac
}

_orch_init_is_frontend_framework() {
    case "$1" in
        react|next|vue|svelte) return 0 ;;
        *) return 1 ;;
    esac
}

_orch_init_build_suggestions() {
    _ORCH_INIT_SUGGESTED_AGENTS=()
    local agent_num=1

    _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-ceo|CEO — strategy & vision|docs/strategy/|3")
    (( agent_num++ )) || true
    _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-cto|CTO — architecture|docs/architecture/|2")
    (( agent_num++ )) || true
    _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-pm|PM — coordination|prompts/|0")
    (( agent_num++ )) || true

    local has_backend=0
    local lang
    for lang in "${!_ORCH_INIT_LANGUAGES[@]}"; do
        if _orch_init_is_backend_lang "$lang"; then
            has_backend=1
            break
        fi
    done
    [[ -n "${_ORCH_INIT_FRAMEWORKS[express]:-}" ]] && has_backend=1  || true
    [[ -n "${_ORCH_INIT_FRAMEWORKS[django]:-}" ]]  && has_backend=1  || true
    [[ -n "${_ORCH_INIT_FRAMEWORKS[flask]:-}" ]]    && has_backend=1 || true
    [[ -n "${_ORCH_INIT_FRAMEWORKS[fastapi]:-}" ]]  && has_backend=1 || true

    if [[ $has_backend -eq 1 ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-backend|Backend — core logic|src/ lib/ scripts/|1")
        (( agent_num++ )) || true
    fi

    if [[ -n "${_ORCH_INIT_FRAMEWORKS[tauri]:-}" ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-tauri-rust|Tauri Rust — desktop backend|src-tauri/|1")
        (( agent_num++ )) || true
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-tauri-ui|Tauri UI — desktop frontend|src/ components/|1")
        (( agent_num++ )) || true
    else
        local has_frontend=0
        local fw
        for fw in "${!_ORCH_INIT_FRAMEWORKS[@]}"; do
            if _orch_init_is_frontend_framework "$fw"; then
                has_frontend=1
                break
            fi
        done

        if [[ $has_frontend -eq 1 ]]; then
            _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-frontend|Frontend — UI|app/ components/ src/|1")
            (( agent_num++ )) || true
        fi
    fi

    if [[ -n "${_ORCH_INIT_FRAMEWORKS[ios]:-}" ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-ios|iOS — mobile app|ios/|1")
        (( agent_num++ )) || true
    fi

    if [[ ${#_ORCH_INIT_TEST_FRAMEWORKS[@]} -gt 0 ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-qa|QA — testing & quality|tests/|3")
        (( agent_num++ )) || true
    fi

    if [[ ${#_ORCH_INIT_CI_SYSTEMS[@]} -gt 0 ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-devops|DevOps — CI/CD & infrastructure|.github/ .gitlab/|2")
        (( agent_num++ )) || true
    fi

    if [[ $_ORCH_INIT_HAS_MONOREPO -eq 1 ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-infra|Infrastructure — monorepo & tooling|packages/ tools/|2")
        (( agent_num++ )) || true
    fi

    if [[ ${#_ORCH_INIT_SUGGESTED_AGENTS[@]} -gt 3 ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-security|Security — threat modeling|reports/|3")
        (( agent_num++ )) || true
    fi
}

_orch_init_generate_prompt_content() {
    local agent_id="$1"
    local role="$2"
    local ownership="$3"

    local role_name="${role%%—*}"
    role_name="${role_name%% }"
    local role_desc="${role#*— }"
    [[ "$role_desc" == "$role" ]] && role_desc="$role_name responsibilities"

    cat <<PROMPT_EOF
# =============================================================================
# ${agent_id} — ${role}
# =============================================================================
#
# Generated by: orch_init_generate_prompts
# Project: ${_ORCH_INIT_PROJECT_DIR##*/}

## Role
You are the **${role_name}** agent. Your responsibility: ${role_desc}.

## File Ownership
You own these paths — only modify files within your ownership:
$(for p in ${ownership}; do printf -- '- \`%s\`\n' "$p"; done)

## Current Tasks
<!-- Replace with actual tasks each cycle -->
1. [ ] Review current state of owned files
2. [ ] Identify improvements or issues
3. [ ] Implement changes within your ownership boundaries

## Rules
1. **Stay in your lane** — only modify files in your ownership paths
2. **Write to shared context** — use prompts/00-shared-context/ to communicate
3. **Read before writing** — always check current state before making changes
4. **No git branch operations** — the orchestrator handles branching
5. **Log decisions** — document why, not just what

## Context
- Read prompts/00-shared-context/context.md for cross-agent updates
- Check the PM's backlog for prioritized work items

## Output Format
When you complete work, summarize:
- What you changed and why
- Files modified (with paths)
- Any blockers or dependencies on other agents
- Suggested follow-up tasks
PROMPT_EOF
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

orch_init_scan() {
    local project_dir="${1:?orch_init_scan requires a project directory}"

    if [[ ! "$project_dir" = /* ]]; then
        project_dir="$(cd "$project_dir" 2>/dev/null && pwd)" || {
            _orch_init_err "could not resolve directory: $1"
            return 1
        }
    fi

    if [[ ! -d "$project_dir" ]]; then
        _orch_init_err "directory does not exist: ${project_dir}"
        return 1
    fi

    _orch_init_reset
    _ORCH_INIT_PROJECT_DIR="$project_dir"

    _orch_init_log "scanning: ${project_dir}"

    _orch_init_detect_languages     "$project_dir"
    _orch_init_detect_frameworks    "$project_dir"
    _orch_init_detect_pkg_managers  "$project_dir"
    _orch_init_detect_test_frameworks "$project_dir"
    _orch_init_detect_ci            "$project_dir"
    _orch_init_detect_features      "$project_dir"

    _orch_init_build_suggestions

    _ORCH_INIT_SCANNED=1

    _orch_init_log "scan complete — ${#_ORCH_INIT_LANGUAGES[@]} languages, ${#_ORCH_INIT_FRAMEWORKS[@]} frameworks, ${#_ORCH_INIT_SUGGESTED_AGENTS[@]} agents suggested"

    return 0
}

orch_init_suggest_agents() {
    if [[ $_ORCH_INIT_SCANNED -eq 0 ]]; then
        _orch_init_err "no scan has been run — call orch_init_scan first"
        return 1
    fi

    local entry
    for entry in "${_ORCH_INIT_SUGGESTED_AGENTS[@]}"; do
        printf '%s\n' "$entry"
    done
}

orch_init_generate_conf() {
    local output_path="${1:?orch_init_generate_conf requires an output path}"

    if [[ $_ORCH_INIT_SCANNED -eq 0 ]]; then
        _orch_init_err "no scan has been run — call orch_init_scan first"
        return 1
    fi

    local output_dir
    output_dir="$(dirname "$output_path")"
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" || {
            _orch_init_err "could not create directory: ${output_dir}"
            return 1
        }
    fi

    {
        printf '# OrchyStraw — agents.conf\n'
        printf '# Generated by: orch_init_generate_conf\n'
        printf '# Project: %s\n' "${_ORCH_INIT_PROJECT_DIR##*/}"
        printf '# Date: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf '#\n'
        printf '# Format: id | prompt_path | ownership | interval | label\n'
        printf '#\n'
        printf '# interval: 0 = coordinator (runs LAST), 1 = every cycle, N = every Nth cycle\n'
        printf '#\n'

        local entry agent_id role ownership interval label prompt_path

        _orch_init_emit_conf_line() {
            local e="$1"
            IFS='|' read -r agent_id role ownership interval <<< "$e"
            label="$role"
            prompt_path="prompts/${agent_id}/${agent_id}.txt"
            printf '%-12s | %-45s | %-40s | %s | %s\n' \
                "$agent_id" "$prompt_path" "$ownership" "$interval" "$label"
        }

        printf '# ── Coordinator (runs LAST) ──\n'
        for entry in "${_ORCH_INIT_SUGGESTED_AGENTS[@]}"; do
            IFS='|' read -r _ _ _ interval <<< "$entry"
            [[ "$interval" -eq 0 ]] && _orch_init_emit_conf_line "$entry"
        done

        printf '\n# ── Core Cycle Workers ──\n'
        for entry in "${_ORCH_INIT_SUGGESTED_AGENTS[@]}"; do
            IFS='|' read -r _ _ _ interval <<< "$entry"
            [[ "$interval" -eq 1 ]] && _orch_init_emit_conf_line "$entry"
        done

        printf '\n# ── Less Frequent ──\n'
        for entry in "${_ORCH_INIT_SUGGESTED_AGENTS[@]}"; do
            IFS='|' read -r _ _ _ interval <<< "$entry"
            [[ "$interval" -gt 1 ]] && _orch_init_emit_conf_line "$entry"
        done
    } > "$output_path" || {
        _orch_init_err "could not write config file: ${output_path}"
        return 1
    }

    _orch_init_log "generated agents.conf: ${output_path}"
    return 0
}

orch_init_generate_prompts() {
    local output_dir="${1:?orch_init_generate_prompts requires an output directory}"

    if [[ $_ORCH_INIT_SCANNED -eq 0 ]]; then
        _orch_init_err "no scan has been run — call orch_init_scan first"
        return 1
    fi

    local count=0
    local entry agent_id role ownership interval
    local prompt_dir prompt_file

    for entry in "${_ORCH_INIT_SUGGESTED_AGENTS[@]}"; do
        IFS='|' read -r agent_id role ownership interval <<< "$entry"

        prompt_dir="${output_dir}/${agent_id}"
        prompt_file="${prompt_dir}/${agent_id}.txt"

        if [[ ! -d "$prompt_dir" ]]; then
            mkdir -p "$prompt_dir" || {
                _orch_init_err "could not create directory: ${prompt_dir}"
                continue
            }
        fi

        _orch_init_generate_prompt_content "$agent_id" "$role" "$ownership" > "$prompt_file" || {
            _orch_init_err "could not write prompt: ${prompt_file}"
            continue
        }

        (( count++ ))
        _orch_init_log "created prompt: ${prompt_file}"
    done

    printf '%d\n' "$count"
}

orch_init_report() {
    if [[ $_ORCH_INIT_SCANNED -eq 0 ]]; then
        _orch_init_err "no scan has been run — call orch_init_scan first"
        return 1
    fi

    printf '\n'
    printf '=============================================================================\n'
    printf '  OrchyStraw — Project Analysis Report\n'
    printf '=============================================================================\n'
    printf '  Project: %s\n' "${_ORCH_INIT_PROJECT_DIR}"
    printf '=============================================================================\n'
    printf '\n'

    printf '  Languages detected (%d):\n' "${#_ORCH_INIT_LANGUAGES[@]}"
    if [[ ${#_ORCH_INIT_LANGUAGES[@]} -gt 0 ]]; then
        local lang
        for lang in "${!_ORCH_INIT_LANGUAGES[@]}"; do
            printf '    - %s\n' "$lang"
        done
    else
        printf '    (none)\n'
    fi
    printf '\n'

    printf '  Frameworks detected (%d):\n' "${#_ORCH_INIT_FRAMEWORKS[@]}"
    if [[ ${#_ORCH_INIT_FRAMEWORKS[@]} -gt 0 ]]; then
        local fw
        for fw in "${!_ORCH_INIT_FRAMEWORKS[@]}"; do
            printf '    - %s\n' "$fw"
        done
    else
        printf '    (none)\n'
    fi
    printf '\n'

    printf '  Package managers (%d):\n' "${#_ORCH_INIT_PKG_MANAGERS[@]}"
    if [[ ${#_ORCH_INIT_PKG_MANAGERS[@]} -gt 0 ]]; then
        local pm
        for pm in "${!_ORCH_INIT_PKG_MANAGERS[@]}"; do
            printf '    - %s\n' "$pm"
        done
    else
        printf '    (none)\n'
    fi
    printf '\n'

    printf '  Test frameworks (%d):\n' "${#_ORCH_INIT_TEST_FRAMEWORKS[@]}"
    if [[ ${#_ORCH_INIT_TEST_FRAMEWORKS[@]} -gt 0 ]]; then
        local tf
        for tf in "${!_ORCH_INIT_TEST_FRAMEWORKS[@]}"; do
            printf '    - %s\n' "$tf"
        done
    else
        printf '    (none)\n'
    fi
    printf '\n'

    printf '  CI/CD systems (%d):\n' "${#_ORCH_INIT_CI_SYSTEMS[@]}"
    if [[ ${#_ORCH_INIT_CI_SYSTEMS[@]} -gt 0 ]]; then
        local ci
        for ci in "${!_ORCH_INIT_CI_SYSTEMS[@]}"; do
            printf '    - %s\n' "$ci"
        done
    else
        printf '    (none)\n'
    fi
    printf '\n'

    printf '  Features:\n'
    printf '    - Monorepo:  %s\n' "$( [[ $_ORCH_INIT_HAS_MONOREPO -eq 1 ]] && echo "yes" || echo "no" )"
    printf '    - Docker:    %s\n' "$( [[ $_ORCH_INIT_HAS_DOCKER -eq 1 ]]   && echo "yes" || echo "no" )"
    printf '    - Database:  %s\n' "$( [[ $_ORCH_INIT_HAS_DATABASE -eq 1 ]]  && echo "yes" || echo "no" )"
    printf '\n'

    printf '=============================================================================\n'
    printf '  Suggested Agent Team (%d agents)\n' "${#_ORCH_INIT_SUGGESTED_AGENTS[@]}"
    printf '=============================================================================\n'
    printf '\n'
    printf '  %-14s %-35s %-25s %s\n' "ID" "Role" "Ownership" "Interval"
    printf '  %-14s %-35s %-25s %s\n' "--------------" "-----------------------------------" "-------------------------" "--------"

    local entry agent_id role ownership interval
    for entry in "${_ORCH_INIT_SUGGESTED_AGENTS[@]}"; do
        IFS='|' read -r agent_id role ownership interval <<< "$entry"
        local interval_label
        case "$interval" in
            0) interval_label="coordinator" ;;
            1) interval_label="every cycle" ;;
            *) interval_label="every ${interval} cycles" ;;
        esac
        printf '  %-14s %-35s %-25s %s\n' "$agent_id" "$role" "$ownership" "$interval_label"
    done

    printf '\n'
    printf '=============================================================================\n'
    printf '  This is a SUGGESTION. Review and adjust before applying.\n'
    printf '  Run orch_init_generate_conf and orch_init_generate_prompts to scaffold.\n'
    printf '=============================================================================\n'
    printf '\n'
}

orch_init_detected_languages() {
    if [[ ${#_ORCH_INIT_LANGUAGES[@]} -eq 0 ]]; then
        return 0
    fi
    local langs=()
    local lang
    for lang in "${!_ORCH_INIT_LANGUAGES[@]}"; do
        langs+=("$lang")
    done
    printf '%s\n' "${langs[*]}"
}

orch_init_detected_frameworks() {
    if [[ ${#_ORCH_INIT_FRAMEWORKS[@]} -eq 0 ]]; then
        return 0
    fi
    local fws=()
    local fw
    for fw in "${!_ORCH_INIT_FRAMEWORKS[@]}"; do
        fws+=("$fw")
    done
    printf '%s\n' "${fws[*]}"
}

orch_init_has_feature() {
    local feature="${1:?orch_init_has_feature requires a feature name}"

    case "$feature" in
        monorepo)  [[ $_ORCH_INIT_HAS_MONOREPO -eq 1 ]] ;;
        ci)        [[ ${#_ORCH_INIT_CI_SYSTEMS[@]} -gt 0 ]] ;;
        tests)     [[ ${#_ORCH_INIT_TEST_FRAMEWORKS[@]} -gt 0 ]] ;;
        docker)    [[ $_ORCH_INIT_HAS_DOCKER -eq 1 ]] ;;
        database)  [[ $_ORCH_INIT_HAS_DATABASE -eq 1 ]] ;;
        *)
            _orch_init_err "unknown feature: ${feature} (valid: monorepo, ci, tests, docker, database)"
            return 1
            ;;
    esac
}

# ===========================================================================
# v0.4.0 — Interactive Mode, Template Marketplace, Existing Detection, Migration
# ===========================================================================

# ---------------------------------------------------------------------------
# orch_init_detect_existing — check if project already has OrchyStraw setup
#
# Looks for agents.conf, prompts/, src/core/, CLAUDE.md
# Returns: 0 if existing setup found, 1 if fresh project
# Sets: _ORCH_INIT_EXISTING_VERSION
# ---------------------------------------------------------------------------
orch_init_detect_existing() {
    local project_dir="${1:?orch_init_detect_existing requires a project directory}"

    _ORCH_INIT_EXISTING_VERSION=""
    local signals=0

    [[ -f "${project_dir}/agents.conf" ]] && signals=$((signals + 1))
    [[ -d "${project_dir}/prompts" ]] && signals=$((signals + 1))
    [[ -d "${project_dir}/src/core" ]] && signals=$((signals + 1))
    [[ -f "${project_dir}/CLAUDE.md" ]] && signals=$((signals + 1))

    if [[ $signals -eq 0 ]]; then
        _orch_init_log "no existing OrchyStraw setup detected"
        return 1
    fi

    # Detect version by checking for version-specific features
    if [[ -f "${project_dir}/agents.conf" ]]; then
        local col_count
        col_count=$(grep -v '^#' "${project_dir}/agents.conf" 2>/dev/null | grep -v '^$' | head -1 | awk -F'|' '{print NF}')

        if [[ "${col_count:-0}" -ge 9 ]]; then
            _ORCH_INIT_EXISTING_VERSION="0.4"
        elif [[ "${col_count:-0}" -ge 8 ]]; then
            _ORCH_INIT_EXISTING_VERSION="0.3"
        elif [[ "${col_count:-0}" -ge 5 ]]; then
            _ORCH_INIT_EXISTING_VERSION="0.2"
        else
            _ORCH_INIT_EXISTING_VERSION="0.1"
        fi
    fi

    _orch_init_log "existing OrchyStraw setup detected (v${_ORCH_INIT_EXISTING_VERSION:-unknown}, ${signals}/4 signals)"
    return 0
}

# ---------------------------------------------------------------------------
# orch_init_existing_version — get detected version string
# ---------------------------------------------------------------------------
orch_init_existing_version() {
    echo "${_ORCH_INIT_EXISTING_VERSION:-}"
}

# ---------------------------------------------------------------------------
# Template Marketplace — predefined project templates
# ---------------------------------------------------------------------------

# _orch_init_register_templates — populate built-in templates
_orch_init_register_templates() {
    _ORCH_INIT_TEMPLATES=()

    # Each template: "name" -> "description|languages|agents_pattern"
    _ORCH_INIT_TEMPLATES["solo-dev"]="Single developer with one agent|any|ceo,backend,qa"
    _ORCH_INIT_TEMPLATES["fullstack-saas"]="Full-stack SaaS with frontend + backend + devops|typescript,python|ceo,cto,pm,backend,frontend,qa,devops,security"
    _ORCH_INIT_TEMPLATES["api-service"]="Backend API microservice|python,go,rust|ceo,cto,pm,backend,qa,devops,security"
    _ORCH_INIT_TEMPLATES["mobile-app"]="Mobile app with iOS/Android|swift,kotlin|ceo,cto,pm,ios,android,qa,security"
    _ORCH_INIT_TEMPLATES["data-pipeline"]="Data engineering pipeline|python|ceo,cto,pm,backend,data-eng,qa"
    _ORCH_INIT_TEMPLATES["monorepo"]="Monorepo with multiple packages|typescript|ceo,cto,pm,backend,frontend,infra,qa,devops,security"
    _ORCH_INIT_TEMPLATES["open-source"]="Open source library|any|ceo,backend,qa,docs"
    _ORCH_INIT_TEMPLATES["cli-tool"]="Command-line tool|rust,go,python|ceo,backend,qa,docs"
}

# ---------------------------------------------------------------------------
# orch_init_list_templates — list available templates
# Outputs: one template per line "name|description"
# ---------------------------------------------------------------------------
orch_init_list_templates() {
    _orch_init_register_templates

    local name
    for name in $(printf '%s\n' "${!_ORCH_INIT_TEMPLATES[@]}" | sort); do
        local entry="${_ORCH_INIT_TEMPLATES[$name]}"
        local desc="${entry%%|*}"
        printf '%s|%s\n' "$name" "$desc"
    done
}

# ---------------------------------------------------------------------------
# orch_init_apply_template — apply a template preset to the scan results
#
# Overrides _ORCH_INIT_SUGGESTED_AGENTS with the template's agent list.
# Args: $1 — template name
# Returns: 0 on success, 1 if template not found
# ---------------------------------------------------------------------------
orch_init_apply_template() {
    local template_name="${1:?orch_init_apply_template requires a template name}"
    _orch_init_register_templates

    local entry="${_ORCH_INIT_TEMPLATES[$template_name]:-}"
    if [[ -z "$entry" ]]; then
        _orch_init_err "unknown template: ${template_name}"
        _orch_init_err "available: $(printf '%s ' "${!_ORCH_INIT_TEMPLATES[@]}")"
        return 1
    fi

    local agents_csv
    agents_csv=$(echo "$entry" | awk -F'|' '{print $3}')

    _ORCH_INIT_SUGGESTED_AGENTS=()
    local agent_num=1
    local IFS=','
    local -a agent_names
    read -ra agent_names <<< "$agents_csv"

    local role_map_ceo="CEO — strategy & vision|docs/strategy/|3"
    local role_map_cto="CTO — architecture|docs/architecture/|2"
    local role_map_pm="PM — coordination|prompts/|0"
    local role_map_backend="Backend — core logic|src/ lib/|1"
    local role_map_frontend="Frontend — UI|app/ components/ src/|1"
    local role_map_qa="QA — testing & quality|tests/|3"
    local role_map_devops="DevOps — CI/CD & infrastructure|.github/|2"
    local role_map_security="Security — threat modeling|reports/|3"
    local role_map_ios="iOS — mobile app|ios/|1"
    local role_map_android="Android — mobile app|android/|1"
    local role_map_infra="Infrastructure — monorepo & tooling|packages/ tools/|2"
    local role_map_docs="Docs — documentation|docs/|2"
    local role_map_data_eng="Data Engineering — pipelines|pipelines/ data/|1"

    for agent in "${agent_names[@]}"; do
        agent="${agent#"${agent%%[![:space:]]*}"}"
        agent="${agent%"${agent##*[![:space:]]}"}"
        local varname="role_map_${agent//-/_}"
        local role_str="${!varname:-${agent} — ${agent}|src/|1}"

        local id_num
        id_num=$(printf '%02d' $agent_num)
        _ORCH_INIT_SUGGESTED_AGENTS+=("${id_num}-${agent}|${role_str}")
        agent_num=$((agent_num + 1))
    done

    _orch_init_log "applied template: ${template_name} (${#_ORCH_INIT_SUGGESTED_AGENTS[@]} agents)"
    return 0
}

# ---------------------------------------------------------------------------
# orch_init_deploy_template — copy template files to a target directory
#
# Copies agents.conf, CLAUDE.md, README.md, and prompts/ from a template
# directory, performing string replacements for project name and date.
#
# Args:
#   $1 — template name (saas, api, content)
#   $2 — target directory
#   $3 — project name (optional, defaults to target dir basename)
#
# Returns: 0 on success, 1 on failure
# ---------------------------------------------------------------------------
orch_init_deploy_template() {
    local template_name="${1:?orch_init_deploy_template requires a template name}"
    local target_dir="${2:?orch_init_deploy_template requires a target directory}"
    local project_name="${3:-}"

    # Resolve ORCH_ROOT (where OrchyStraw is installed)
    local orch_root="${ORCH_ROOT:-}"
    if [[ -z "$orch_root" ]]; then
        # Try to find it relative to this script
        local script_path="${BASH_SOURCE[0]}"
        if [[ -n "$script_path" ]]; then
            orch_root="$(cd "$(dirname "$script_path")/../.." 2>/dev/null && pwd)"
        fi
    fi

    local template_dir="${orch_root}/template/${template_name}"
    if [[ ! -d "$template_dir" ]]; then
        _orch_init_err "template directory not found: ${template_dir}"
        _orch_init_err "available templates: $(ls "${orch_root}/template/" 2>/dev/null | tr '\n' ' ')"
        return 1
    fi

    # Resolve target directory
    if [[ ! "$target_dir" = /* ]]; then
        target_dir="$(pwd)/${target_dir}"
    fi

    # Derive project name from target dir basename if not provided
    if [[ -z "$project_name" ]]; then
        project_name="$(basename "$target_dir")"
    fi

    local current_date
    current_date="$(date '+%Y-%m-%d %H:%M:%S')"

    _orch_init_log "deploying template '${template_name}' to '${target_dir}'"
    _orch_init_log "project name: ${project_name}"

    # Create target directory if it doesn't exist
    mkdir -p "$target_dir" || {
        _orch_init_err "could not create target directory: ${target_dir}"
        return 1
    }

    # Create shared context directory
    mkdir -p "${target_dir}/prompts/00-shared-context" || true

    # Copy template files recursively
    cp -R "${template_dir}/"* "${target_dir}/" 2>/dev/null || {
        _orch_init_err "failed to copy template files from ${template_dir}"
        return 1
    }

    # Perform string replacements in all copied files
    local file
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            # Replace placeholders
            if command -v sed >/dev/null 2>&1; then
                sed -i '' \
                    -e "s|{{PROJECT_NAME}}|${project_name}|g" \
                    -e "s|{{DATE}}|${current_date}|g" \
                    "$file" 2>/dev/null || \
                sed -i \
                    -e "s|{{PROJECT_NAME}}|${project_name}|g" \
                    -e "s|{{DATE}}|${current_date}|g" \
                    "$file" 2>/dev/null || true
            fi
        fi
    done < <(find "$target_dir" -type f \( -name "*.conf" -o -name "*.md" -o -name "*.txt" \) -print0 2>/dev/null)

    # Create empty shared context file
    if [[ ! -f "${target_dir}/prompts/00-shared-context/context.md" ]]; then
        cat > "${target_dir}/prompts/00-shared-context/context.md" <<CTXEOF
# ${project_name} — Shared Context

## Cross-Agent Communication
Agents write their updates here each cycle. Reset at the start of each new cycle.

---

<!-- Agent updates will appear below -->
CTXEOF
    fi

    # Count what was deployed
    local file_count
    file_count=$(find "$target_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
    local prompt_count
    prompt_count=$(find "${target_dir}/prompts" -name "*.txt" -type f 2>/dev/null | wc -l | tr -d ' ')

    _orch_init_log "deployed ${file_count} files (${prompt_count} agent prompts)"
    _orch_init_log "target: ${target_dir}"

    printf 'Template "%s" deployed to %s\n' "$template_name" "$target_dir"
    printf '  Project name: %s\n' "$project_name"
    printf '  Files: %s\n' "$file_count"
    printf '  Agent prompts: %s\n' "$prompt_count"
    printf '  Config: %s/agents.conf\n' "$target_dir"
    printf '\nNext steps:\n'
    printf '  1. cd %s\n' "$target_dir"
    printf '  2. Review agents.conf and adjust ownership paths\n'
    printf '  3. Edit prompts in prompts/ with your specific tasks\n'
    printf '  4. Run: ./scripts/auto-agent.sh orchestrate\n'

    return 0
}

# ---------------------------------------------------------------------------
# orch_init_migrate — migrate older agents.conf format to current version
#
# Handles:
#   v0.1/v0.2 (5-column) → v0.3+ (5-column, unchanged format but validated)
#   Adds missing fields with sensible defaults
#
# Args: $1 — path to agents.conf
# Outputs: migrated content to stdout
# Returns: 0 on success
# ---------------------------------------------------------------------------
orch_init_migrate() {
    local conf_file="${1:?orch_init_migrate requires a config file path}"

    if [[ ! -f "$conf_file" ]]; then
        _orch_init_err "config file not found: ${conf_file}"
        return 1
    fi

    local migrated=0

    while IFS= read -r line; do
        # Pass through comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// /}" ]]; then
            printf '%s\n' "$line"
            continue
        fi

        local col_count
        col_count=$(echo "$line" | awk -F'|' '{print NF}')

        if [[ "$col_count" -lt 5 ]]; then
            # Old format: id | prompt | ownership (3 cols) → add interval + label
            IFS='|' read -ra fields <<< "$line"
            local id="${fields[0]:-}"
            local prompt="${fields[1]:-}"
            local ownership="${fields[2]:-}"
            id="${id#"${id%%[![:space:]]*}"}"
            id="${id%"${id##*[![:space:]]}"}"
            printf '%s | %s | %s | 1 | %s\n' "$id" "$prompt" "$ownership" "$id"
            migrated=1
        else
            printf '%s\n' "$line"
        fi
    done < "$conf_file"

    if [[ $migrated -eq 1 ]]; then
        _orch_init_log "migrated config format to v0.3+"
    else
        _orch_init_log "config already in current format"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# orch_init_interactive — guided setup wizard (non-TTY safe)
#
# When stdin is a TTY, prompts the user for choices.
# When not a TTY, uses auto-detection defaults.
#
# Args: $1 — project directory
# Returns: 0 on success
# Sets: all _ORCH_INIT_* state, ready for generate_conf/generate_prompts
# ---------------------------------------------------------------------------
orch_init_interactive() {
    local project_dir="${1:?orch_init_interactive requires a project directory}"
    _ORCH_INIT_INTERACTIVE_MODE=1

    # Step 1: Check for existing setup
    if orch_init_detect_existing "$project_dir"; then
        local ver
        ver=$(orch_init_existing_version)
        printf '\n  Existing OrchyStraw setup detected (v%s)\n' "$ver"
        printf '  Options: [s]can and merge, [f]resh start, [m]igrate config\n'

        if [[ -t 0 ]]; then
            local choice
            read -r -p '  Choice [s/f/m]: ' choice < /dev/tty
            case "${choice:-s}" in
                f|F) _orch_init_reset ;;
                m|M)
                    if [[ -f "${project_dir}/agents.conf" ]]; then
                        printf '\n  Migrated config:\n'
                        orch_init_migrate "${project_dir}/agents.conf"
                        printf '\n'
                    fi
                    ;;
            esac
        fi
    fi

    # Step 2: Scan project
    orch_init_scan "$project_dir"

    # Step 3: Template selection (if TTY)
    if [[ -t 0 ]]; then
        printf '\n  Available templates:\n'
        local templates
        templates=$(orch_init_list_templates)
        local idx=0
        local -a tpl_names=()
        while IFS='|' read -r name desc; do
            idx=$((idx + 1))
            printf '    %d) %s — %s\n' "$idx" "$name" "$desc"
            tpl_names+=("$name")
        done <<< "$templates"
        printf '    0) Auto-detect (use scan results)\n'

        local tpl_choice
        read -r -p '  Template [0]: ' tpl_choice < /dev/tty
        if [[ -n "$tpl_choice" && "$tpl_choice" != "0" ]] && [[ "$tpl_choice" =~ ^[0-9]+$ ]]; then
            local sel_idx=$((tpl_choice - 1))
            if [[ $sel_idx -ge 0 && $sel_idx -lt ${#tpl_names[@]} ]]; then
                orch_init_apply_template "${tpl_names[$sel_idx]}"
            fi
        fi
    fi

    # Step 4: Report
    orch_init_report
    _ORCH_INIT_INTERACTIVE_MODE=0

    return 0
}
