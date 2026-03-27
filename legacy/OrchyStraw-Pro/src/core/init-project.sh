#!/usr/bin/env bash
# =============================================================================
# init-project.sh — Project analyzer & agent blueprint generator (#29)
#
# Scans a target project directory to detect languages, frameworks, package
# managers, test frameworks, and CI/CD config. Generates a suggested
# agents.conf and scaffold prompt files based on what was found.
#
# Usage:
#   source src/core/init-project.sh
#
#   orch_init_scan "/path/to/project"
#   orch_init_report
#   orch_init_generate_conf  "/path/to/output/agents.conf"
#   orch_init_generate_prompts "/path/to/output/prompts"
#
# Requires: bash 4.2+ (declare -gA)
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_INIT_PROJECT_LOADED:-}" ]] && return 0
readonly _ORCH_INIT_PROJECT_LOADED=1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
declare -g  _ORCH_INIT_PROJECT_DIR=""
declare -g  _ORCH_INIT_SCANNED=0
declare -gA _ORCH_INIT_LANGUAGES=()       # lang_name → 1
declare -gA _ORCH_INIT_FRAMEWORKS=()      # framework_name → 1
declare -gA _ORCH_INIT_PKG_MANAGERS=()    # pkg_manager → 1
declare -gA _ORCH_INIT_TEST_FRAMEWORKS=() # test_framework → 1
declare -gA _ORCH_INIT_CI_SYSTEMS=()      # ci_system → 1
declare -g  _ORCH_INIT_HAS_MONOREPO=0
declare -g  _ORCH_INIT_HAS_DOCKER=0
declare -g  _ORCH_INIT_HAS_DATABASE=0
declare -ga _ORCH_INIT_SUGGESTED_AGENTS=() # "id|role|ownership|interval"

# Directories to exclude from scanning
readonly _ORCH_INIT_EXCLUDE_DIRS="node_modules .git vendor __pycache__ .venv venv dist build target .next .nuxt"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _orch_init_log <message>
#   Print an informational message to stderr.
_orch_init_log() {
    printf '[init-project] %s\n' "$1" >&2
}

# _orch_init_err <message>
#   Print an error message to stderr.
_orch_init_err() {
    printf '[init-project] ERROR: %s\n' "$1" >&2
}

# _orch_init_reset — clear all internal state for a fresh scan
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

# _orch_init_build_find_excludes
#   Build the -not -path arguments for find based on _ORCH_INIT_EXCLUDE_DIRS.
#   Prints the arguments to stdout.
_orch_init_build_find_excludes() {
    local dir
    local first=1
    for dir in ${_ORCH_INIT_EXCLUDE_DIRS}; do
        if [[ $first -eq 1 ]]; then
            printf '%s' "( "
            first=0
        else
            printf '%s' " -o "
        fi
        printf '%s' "-name ${dir} -type d"
    done
    printf '%s' " ) -prune -o"
}

# _orch_init_find_files <project_dir> <pattern>
#   Find files matching pattern, excluding unwanted directories.
#   Prints matching file paths, one per line.
_orch_init_find_files() {
    local project_dir="$1"
    local pattern="$2"

    find "$project_dir" -maxdepth 3 \
        \( -name "node_modules" -o -name ".git" -o -name "vendor" \
           -o -name "__pycache__" -o -name ".venv" -o -name "venv" \
           -o -name "dist" -o -name "build" -o -name "target" \
           -o -name ".next" -o -name ".nuxt" \) -prune \
        -o -name "$pattern" -type f -print 2>/dev/null
}

# _orch_init_file_exists <project_dir> <filename>
#   Check if a file with the given name exists in the project (max depth 3).
#   Returns 0 if found, 1 otherwise.
_orch_init_file_exists() {
    local project_dir="$1"
    local filename="$2"
    local result

    result="$(_orch_init_find_files "$project_dir" "$filename" | head -1)"
    [[ -n "$result" ]]
}

# _orch_init_has_ext <project_dir> <extension>
#   Check if any file with the given extension exists in the project.
#   Returns 0 if found, 1 otherwise.
_orch_init_has_ext() {
    local project_dir="$1"
    local ext="$2"
    local result

    result="$(_orch_init_find_files "$project_dir" "*${ext}" | head -1)"
    [[ -n "$result" ]]
}

# _orch_init_pkg_json_has_dep <project_dir> <dep_name>
#   Check if package.json in the project root contains a dependency.
#   Searches dependencies, devDependencies, and peerDependencies.
#   Returns 0 if found, 1 otherwise.
_orch_init_pkg_json_has_dep() {
    local project_dir="$1"
    local dep_name="$2"
    local pkg_json="${project_dir}/package.json"

    [[ -f "$pkg_json" ]] || return 1

    # Simple grep — no jq dependency required
    grep -q "\"${dep_name}\"" "$pkg_json" 2>/dev/null
}

# _orch_init_requirements_has <project_dir> <package_name>
#   Check if requirements.txt contains a package name.
#   Returns 0 if found, 1 otherwise.
_orch_init_requirements_has() {
    local project_dir="$1"
    local pkg="$2"

    local req_file
    for req_file in "${project_dir}/requirements.txt" "${project_dir}/requirements-dev.txt" "${project_dir}/requirements_dev.txt"; do
        if [[ -f "$req_file" ]]; then
            grep -qi "^${pkg}" "$req_file" 2>/dev/null && return 0
        fi
    done

    # Also check pyproject.toml and setup.cfg
    if [[ -f "${project_dir}/pyproject.toml" ]]; then
        grep -qi "${pkg}" "${project_dir}/pyproject.toml" 2>/dev/null && return 0
    fi
    if [[ -f "${project_dir}/setup.cfg" ]]; then
        grep -qi "${pkg}" "${project_dir}/setup.cfg" 2>/dev/null && return 0
    fi

    return 1
}

# _orch_init_detect_languages <project_dir>
#   Detect programming languages by file extension presence.
_orch_init_detect_languages() {
    local dir="$1"

    _orch_init_has_ext "$dir" ".sh"  && _ORCH_INIT_LANGUAGES[bash]=1    || true
    _orch_init_has_ext "$dir" ".py"  && _ORCH_INIT_LANGUAGES[python]=1  || true
    _orch_init_has_ext "$dir" ".js"  && _ORCH_INIT_LANGUAGES[javascript]=1  || true
    _orch_init_has_ext "$dir" ".jsx" && _ORCH_INIT_LANGUAGES[javascript]=1  || true
    _orch_init_has_ext "$dir" ".ts"  && _ORCH_INIT_LANGUAGES[typescript]=1  || true
    _orch_init_has_ext "$dir" ".tsx" && _ORCH_INIT_LANGUAGES[typescript]=1  || true

    # Rust requires both .rs files AND Cargo.toml
    if _orch_init_has_ext "$dir" ".rs" && [[ -f "${dir}/Cargo.toml" ]]; then
        _ORCH_INIT_LANGUAGES[rust]=1
    fi

    # Go requires both .go files AND go.mod
    if _orch_init_has_ext "$dir" ".go" && [[ -f "${dir}/go.mod" ]]; then
        _ORCH_INIT_LANGUAGES[go]=1
    fi

    _orch_init_has_ext "$dir" ".swift" && _ORCH_INIT_LANGUAGES[swift]=1  || true
    _orch_init_has_ext "$dir" ".java"  && _ORCH_INIT_LANGUAGES[java]=1   || true
    _orch_init_has_ext "$dir" ".rb"    && _ORCH_INIT_LANGUAGES[ruby]=1   || true
}

# _orch_init_detect_frameworks <project_dir>
#   Detect frameworks by config files and dependency declarations.
_orch_init_detect_frameworks() {
    local dir="$1"

    # JavaScript/TypeScript frameworks
    _orch_init_pkg_json_has_dep "$dir" "react"   && _ORCH_INIT_FRAMEWORKS[react]=1   || true
    _orch_init_pkg_json_has_dep "$dir" "vue"     && _ORCH_INIT_FRAMEWORKS[vue]=1     || true
    _orch_init_pkg_json_has_dep "$dir" "express" && _ORCH_INIT_FRAMEWORKS[express]=1 || true

    _orch_init_file_exists "$dir" "next.config.*"    && _ORCH_INIT_FRAMEWORKS[next]=1    || true
    _orch_init_file_exists "$dir" "vue.config.*"     && _ORCH_INIT_FRAMEWORKS[vue]=1     || true
    _orch_init_file_exists "$dir" "svelte.config.*"  && _ORCH_INIT_FRAMEWORKS[svelte]=1  || true
    _orch_init_file_exists "$dir" "tauri.conf.json"  && _ORCH_INIT_FRAMEWORKS[tauri]=1   || true

    # Python frameworks
    _orch_init_requirements_has "$dir" "django"  && _ORCH_INIT_FRAMEWORKS[django]=1  || true
    _orch_init_requirements_has "$dir" "flask"   && _ORCH_INIT_FRAMEWORKS[flask]=1   || true
    _orch_init_requirements_has "$dir" "fastapi" && _ORCH_INIT_FRAMEWORKS[fastapi]=1 || true

    # iOS
    if _orch_init_file_exists "$dir" "*.xcodeproj" || [[ -f "${dir}/Package.swift" ]]; then
        _ORCH_INIT_FRAMEWORKS[ios]=1
    fi
}

# _orch_init_detect_pkg_managers <project_dir>
#   Detect package managers by lockfile / config presence.
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

    # If package.json exists but no lockfile detected, default to npm
    if [[ -f "${dir}/package.json" ]] && \
       [[ -z "${_ORCH_INIT_PKG_MANAGERS[npm]:-}" ]] && \
       [[ -z "${_ORCH_INIT_PKG_MANAGERS[yarn]:-}" ]] && \
       [[ -z "${_ORCH_INIT_PKG_MANAGERS[pnpm]:-}" ]]; then
        _ORCH_INIT_PKG_MANAGERS[npm]=1
    fi
}

# _orch_init_detect_test_frameworks <project_dir>
#   Detect test frameworks by config files and dependencies.
_orch_init_detect_test_frameworks() {
    local dir="$1"

    _orch_init_pkg_json_has_dep "$dir" "jest"   && _ORCH_INIT_TEST_FRAMEWORKS[jest]=1    || true
    _orch_init_pkg_json_has_dep "$dir" "vitest" && _ORCH_INIT_TEST_FRAMEWORKS[vitest]=1  || true
    _orch_init_file_exists "$dir" "jest.config.*"   && _ORCH_INIT_TEST_FRAMEWORKS[jest]=1   || true
    _orch_init_file_exists "$dir" "vitest.config.*"  && _ORCH_INIT_TEST_FRAMEWORKS[vitest]=1 || true

    _orch_init_requirements_has "$dir" "pytest" && _ORCH_INIT_TEST_FRAMEWORKS[pytest]=1  || true
    { [[ -f "${dir}/pytest.ini" ]] || [[ -f "${dir}/conftest.py" ]]; } && _ORCH_INIT_TEST_FRAMEWORKS[pytest]=1  || true

    # Cargo test is implicit if Rust is detected
    [[ -n "${_ORCH_INIT_LANGUAGES[rust]:-}" ]] && _ORCH_INIT_TEST_FRAMEWORKS[cargo-test]=1  || true

    # Go test is implicit if Go is detected
    [[ -n "${_ORCH_INIT_LANGUAGES[go]:-}" ]] && _ORCH_INIT_TEST_FRAMEWORKS[go-test]=1  || true

    # XCTest if iOS/Swift detected
    if [[ -n "${_ORCH_INIT_FRAMEWORKS[ios]:-}" ]] || [[ -n "${_ORCH_INIT_LANGUAGES[swift]:-}" ]]; then
        _orch_init_file_exists "$dir" "*Tests.swift" && _ORCH_INIT_TEST_FRAMEWORKS[xctest]=1  || true
    fi
}

# _orch_init_detect_ci <project_dir>
#   Detect CI/CD systems by config file presence.
_orch_init_detect_ci() {
    local dir="$1"

    [[ -d "${dir}/.github/workflows" ]] && _ORCH_INIT_CI_SYSTEMS[github-actions]=1  || true
    [[ -f "${dir}/.gitlab-ci.yml" ]]    && _ORCH_INIT_CI_SYSTEMS[gitlab-ci]=1      || true
    [[ -f "${dir}/.circleci/config.yml" ]] && _ORCH_INIT_CI_SYSTEMS[circleci]=1    || true
    [[ -f "${dir}/Jenkinsfile" ]]       && _ORCH_INIT_CI_SYSTEMS[jenkins]=1        || true
}

# _orch_init_detect_features <project_dir>
#   Detect monorepo, Docker, database usage.
_orch_init_detect_features() {
    local dir="$1"

    # Monorepo detection
    if [[ -f "${dir}/lerna.json" ]] || [[ -f "${dir}/turbo.json" ]] || [[ -f "${dir}/pnpm-workspace.yaml" ]]; then
        _ORCH_INIT_HAS_MONOREPO=1
    fi
    # Check package.json workspaces field
    if [[ -f "${dir}/package.json" ]]; then
        grep -q '"workspaces"' "${dir}/package.json" 2>/dev/null && _ORCH_INIT_HAS_MONOREPO=1  || true
    fi
    # Cargo workspaces
    if [[ -f "${dir}/Cargo.toml" ]]; then
        grep -q '\[workspace\]' "${dir}/Cargo.toml" 2>/dev/null && _ORCH_INIT_HAS_MONOREPO=1  || true
    fi

    # Docker detection
    { [[ -f "${dir}/Dockerfile" ]] || [[ -f "${dir}/docker-compose.yml" ]] || [[ -f "${dir}/docker-compose.yaml" ]]; } && _ORCH_INIT_HAS_DOCKER=1  || true

    # Database detection (config files, ORMs, migration dirs)
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

# _orch_init_is_backend_lang <lang>
#   Returns 0 if the language is a backend language.
_orch_init_is_backend_lang() {
    case "$1" in
        python|rust|go|java|ruby|bash) return 0 ;;
        *) return 1 ;;
    esac
}

# _orch_init_is_frontend_framework <framework>
#   Returns 0 if the framework is a frontend framework.
_orch_init_is_frontend_framework() {
    case "$1" in
        react|next|vue|svelte) return 0 ;;
        *) return 1 ;;
    esac
}

# _orch_init_build_suggestions
#   Populate _ORCH_INIT_SUGGESTED_AGENTS based on scan results.
_orch_init_build_suggestions() {
    _ORCH_INIT_SUGGESTED_AGENTS=()
    local agent_num=1

    # Always include CEO, CTO, PM
    _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-ceo|CEO — strategy & vision|docs/strategy/|3")
    (( agent_num++ )) || true
    _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-cto|CTO — architecture|docs/architecture/|2")
    (( agent_num++ )) || true
    _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-pm|PM — coordination|prompts/|0")
    (( agent_num++ )) || true

    # Backend agent if backend language detected
    local has_backend=0
    local lang
    for lang in "${!_ORCH_INIT_LANGUAGES[@]}"; do
        if _orch_init_is_backend_lang "$lang"; then
            has_backend=1
            break
        fi
    done
    # Also consider express as a backend framework
    [[ -n "${_ORCH_INIT_FRAMEWORKS[express]:-}" ]] && has_backend=1  || true
    [[ -n "${_ORCH_INIT_FRAMEWORKS[django]:-}" ]]  && has_backend=1  || true
    [[ -n "${_ORCH_INIT_FRAMEWORKS[flask]:-}" ]]    && has_backend=1 || true
    [[ -n "${_ORCH_INIT_FRAMEWORKS[fastapi]:-}" ]]  && has_backend=1 || true

    if [[ $has_backend -eq 1 ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-backend|Backend — core logic|src/ lib/ scripts/|1")
        (( agent_num++ )) || true
    fi

    # Tauri gets separate Rust and UI agents
    if [[ -n "${_ORCH_INIT_FRAMEWORKS[tauri]:-}" ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-tauri-rust|Tauri Rust — desktop backend|src-tauri/|1")
        (( agent_num++ )) || true
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-tauri-ui|Tauri UI — desktop frontend|src/ components/|1")
        (( agent_num++ )) || true
    else
        # Frontend agent if frontend framework detected (and not Tauri)
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

    # iOS agent
    if [[ -n "${_ORCH_INIT_FRAMEWORKS[ios]:-}" ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-ios|iOS — mobile app|ios/|1")
        (( agent_num++ )) || true
    fi

    # QA agent if tests or test framework detected
    if [[ ${#_ORCH_INIT_TEST_FRAMEWORKS[@]} -gt 0 ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-qa|QA — testing & quality|tests/|3")
        (( agent_num++ )) || true
    fi

    # DevOps agent if CI detected
    if [[ ${#_ORCH_INIT_CI_SYSTEMS[@]} -gt 0 ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-devops|DevOps — CI/CD & infrastructure|.github/ .gitlab/|2")
        (( agent_num++ )) || true
    fi

    # Infrastructure agent if monorepo
    if [[ $_ORCH_INIT_HAS_MONOREPO -eq 1 ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-infra|Infrastructure — monorepo & tooling|packages/ tools/|2")
        (( agent_num++ )) || true
    fi

    # Security agent if > 3 agents total (CEO+CTO+PM = 3, so if anything else added)
    if [[ ${#_ORCH_INIT_SUGGESTED_AGENTS[@]} -gt 3 ]]; then
        _ORCH_INIT_SUGGESTED_AGENTS+=("$(printf '%02d' $agent_num)-security|Security — threat modeling|reports/|3")
        (( agent_num++ )) || true
    fi
}

# _orch_init_generate_prompt_content <agent_id> <role> <ownership>
#   Generate the scaffold prompt content for an agent.
#   Prints the content to stdout.
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
$(for p in ${ownership}; do printf -- '- `%s`\n' "$p"; done)

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

# orch_init_scan <project_dir>
#   Scans the project and populates internal state with detected features.
#   Returns 0 on success, 1 on failure.
orch_init_scan() {
    local project_dir="${1:?orch_init_scan requires a project directory}"

    # Resolve to absolute path
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

# orch_init_suggest_agents
#   Based on scan results, returns a list of suggested agent IDs and roles.
#   Returns newline-separated: "agent_id|role|ownership|interval"
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

# orch_init_generate_conf <output_path>
#   Writes a valid agents.conf file based on suggested agents.
#   Format: id | prompt_path | ownership | interval | label
#   Returns 0 on success, 1 on failure.
orch_init_generate_conf() {
    local output_path="${1:?orch_init_generate_conf requires an output path}"

    if [[ $_ORCH_INIT_SCANNED -eq 0 ]]; then
        _orch_init_err "no scan has been run — call orch_init_scan first"
        return 1
    fi

    # Ensure parent directory exists
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

        # Helper to emit one conf line
        _orch_init_emit_conf_line() {
            local e="$1"
            IFS='|' read -r agent_id role ownership interval <<< "$e"
            label="$role"
            prompt_path="prompts/${agent_id}/${agent_id}.txt"
            printf '%-12s | %-45s | %-40s | %s | %s\n' \
                "$agent_id" "$prompt_path" "$ownership" "$interval" "$label"
        }

        # Coordinator (interval=0)
        printf '# ── Coordinator (runs LAST) ──\n'
        for entry in "${_ORCH_INIT_SUGGESTED_AGENTS[@]}"; do
            IFS='|' read -r _ _ _ interval <<< "$entry"
            [[ "$interval" -eq 0 ]] && _orch_init_emit_conf_line "$entry"
        done

        # Core cycle workers (interval=1)
        printf '\n# ── Core Cycle Workers ──\n'
        for entry in "${_ORCH_INIT_SUGGESTED_AGENTS[@]}"; do
            IFS='|' read -r _ _ _ interval <<< "$entry"
            [[ "$interval" -eq 1 ]] && _orch_init_emit_conf_line "$entry"
        done

        # Less frequent (interval>1)
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

# orch_init_generate_prompts <output_dir>
#   Creates scaffold prompt files for each suggested agent.
#   Each prompt includes: role description, file ownership, tasks placeholder, rules.
#   Creates output_dir/XX-role/XX-role.txt for each agent.
#   Returns number of prompts generated (printed to stdout).
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

# orch_init_report
#   Prints a human-readable summary of what was detected and what will be generated.
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

    # Languages
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

    # Frameworks
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

    # Package managers
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

    # Test frameworks
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

    # CI systems
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

    # Features
    printf '  Features:\n'
    printf '    - Monorepo:  %s\n' "$( [[ $_ORCH_INIT_HAS_MONOREPO -eq 1 ]] && echo "yes" || echo "no" )"
    printf '    - Docker:    %s\n' "$( [[ $_ORCH_INIT_HAS_DOCKER -eq 1 ]]   && echo "yes" || echo "no" )"
    printf '    - Database:  %s\n' "$( [[ $_ORCH_INIT_HAS_DATABASE -eq 1 ]]  && echo "yes" || echo "no" )"
    printf '\n'

    # Suggested agents
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

# orch_init_detected_languages
#   Returns space-separated list of detected languages.
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

# orch_init_detected_frameworks
#   Returns space-separated list of detected frameworks.
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

# orch_init_has_feature <feature_name>
#   Returns 0 if feature detected, 1 otherwise.
#   Features: monorepo, ci, tests, docker, database
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

# ---------------------------------------------------------------------------
# orch_init_bootstrap_knowledge [project_root]
#
# Create the knowledge repository structure for a new project.
# Sets up ~/.orchystraw/knowledge/ with default domain directories
# and a project-local .orchystraw/knowledge/ cache.
#
# If knowledge-base.sh is loaded, uses orch_kb_init; otherwise creates
# the directory structure directly.
#
# Default domains: patterns, decisions, anti-patterns, tools, conventions
# ---------------------------------------------------------------------------
orch_init_bootstrap_knowledge() {
    local project_root="${1:-$(pwd)}"
    local home_dir="${ORCHYSTRAW_HOME:-$HOME/.orchystraw}"
    local global_kb="$home_dir/knowledge"
    local local_kb="$project_root/.orchystraw/knowledge"

    local -a default_domains=(patterns decisions anti-patterns tools conventions)

    # Bootstrap global knowledge directory
    if declare -f orch_kb_init >/dev/null 2>&1; then
        orch_kb_init
    else
        mkdir -p "$global_kb"
        [[ -f "$global_kb/index.txt" ]] || touch "$global_kb/index.txt"
    fi

    # Create default domain directories in global KB
    local domain
    for domain in "${default_domains[@]}"; do
        mkdir -p "$global_kb/$domain"
    done

    # Bootstrap project-local knowledge cache
    mkdir -p "$local_kb"
    for domain in "${default_domains[@]}"; do
        mkdir -p "$local_kb/$domain"
    done

    # If knowledge-base is loaded, merge global ↔ local
    if declare -f orch_kb_merge_on_init >/dev/null 2>&1; then
        orch_kb_merge_on_init "$project_root"
    fi

    _orch_init_log "knowledge repository bootstrapped: $global_kb (${#default_domains[@]} domains)"
    printf '%d\n' "${#default_domains[@]}"
}
