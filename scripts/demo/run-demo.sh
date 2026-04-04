#!/usr/bin/env bash
# ============================================
# OrchyStraw — Self-Contained Demo
# ============================================
#
# Creates a temporary project with sample agents, runs 2 orchestration
# cycles in --dry-run mode, showing colorful terminal output suitable
# for recording a demo GIF.
#
# Usage:
#   ./scripts/demo/run-demo.sh
#   ./scripts/demo/run-demo.sh --cycles 3
#   ./scripts/demo/run-demo.sh --no-color
#
# No external dependencies. No API calls. Safe to run anywhere.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Colors ──

USE_COLOR=1
CYCLES=2

_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cycles)   CYCLES="$2"; shift 2 ;;
            --no-color) USE_COLOR=0; shift ;;
            --help|-h)  _usage; exit 0 ;;
            *)          echo "Unknown arg: $1" >&2; exit 1 ;;
        esac
    done
}

_setup_colors() {
    if [[ "$USE_COLOR" -eq 1 ]] && [[ -t 1 ]]; then
        BOLD='\033[1m'
        DIM='\033[2m'
        RESET='\033[0m'
        RED='\033[31m'
        GREEN='\033[32m'
        YELLOW='\033[33m'
        BLUE='\033[34m'
        MAGENTA='\033[35m'
        CYAN='\033[36m'
        ORANGE='\033[38;5;208m'
    else
        BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' ORANGE=''
    fi
}

_banner() {
    printf '\n'
    printf "${ORANGE}${BOLD}"
    printf '  ╔═══════════════════════════════════════════════╗\n'
    printf '  ║                                               ║\n'
    printf '  ║     OrchyStraw  Demo                          ║\n'
    printf '  ║     Multi-Agent AI Coding Orchestration        ║\n'
    printf '  ║                                               ║\n'
    printf '  ╚═══════════════════════════════════════════════╝\n'
    printf "${RESET}\n"
}

_step() {
    local num="$1" text="$2"
    printf "  ${CYAN}${BOLD}[Step %d]${RESET} %s\n" "$num" "$text"
}

_agent_log() {
    local agent="$1" color="$2" msg="$3"
    printf "    ${color}%-12s${RESET} ${DIM}%s${RESET}  %s\n" "$agent" "$(date +%H:%M:%S)" "$msg"
}

_ok() { printf "    ${GREEN}OK${RESET} %s\n" "$*"; }
_info() { printf "  ${DIM}%s${RESET}\n" "$*"; }
_divider() { printf "\n  ${DIM}%s${RESET}\n\n" "────────────────────────────────────────────"; }

_usage() {
    cat <<'EOF'
Usage: run-demo.sh [OPTIONS]

Self-contained OrchyStraw demo. Creates a temp project, configures 3 agents,
and runs orchestration cycles in dry-run mode.

Options:
  --cycles <N>   Number of cycles to simulate (default: 2)
  --no-color     Disable color output
  --help         Show this help

No API calls are made. No external dependencies required.
EOF
}

# ── Create temporary project ──

_create_temp_project() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    DEMO_DIR="$tmpdir/demo-project"
    mkdir -p "$DEMO_DIR"

    # Initialize git repo
    git -C "$DEMO_DIR" init -b main >/dev/null 2>&1
    git -C "$DEMO_DIR" config user.email "demo@orchystraw.dev"
    git -C "$DEMO_DIR" config user.name "OrchyStraw Demo"

    # Create agents.conf
    cat > "$DEMO_DIR/agents.conf" <<'CONF'
# OrchyStraw Demo — agents.conf
# Format: id | prompt_path | ownership | interval | label
03-pm        | prompts/03-pm/03-pm.txt         | prompts/ docs/  | 0 | PM Coordinator
06-developer | prompts/06-developer/06-dev.txt  | src/ scripts/   | 1 | Full-Stack Developer
09-qa        | prompts/09-qa/09-qa.txt          | tests/          | 2 | QA Engineer
CONF

    # Create prompt directories
    mkdir -p "$DEMO_DIR/prompts/00-shared-context"
    mkdir -p "$DEMO_DIR/prompts/03-pm"
    mkdir -p "$DEMO_DIR/prompts/06-developer"
    mkdir -p "$DEMO_DIR/prompts/09-qa"
    mkdir -p "$DEMO_DIR/src"
    mkdir -p "$DEMO_DIR/tests"
    mkdir -p "$DEMO_DIR/docs"

    # Shared context
    cat > "$DEMO_DIR/prompts/00-shared-context/context.md" <<'CTX'
# Shared Context -- Cycle 1
> Agents: read before starting, append before finishing.

## Progress
- Fresh project. Building a TODO API.

## Blockers
- (none)
CTX

    # PM prompt
    cat > "$DEMO_DIR/prompts/03-pm/03-pm.txt" <<'PM'
# PM Coordinator

You coordinate the team. Run LAST each cycle.

## Tasks
1. Read shared context
2. Review all agent output
3. Update prompts with next tasks
4. Track velocity

## Current Sprint
- Sprint 1: Build TODO CRUD API
- 06-developer: implement endpoints
- 09-qa: write integration tests
PM

    # Developer prompt
    cat > "$DEMO_DIR/prompts/06-developer/06-dev.txt" <<'DEV'
# Full-Stack Developer

You build features. Backend + frontend.

## Tasks
1. Read shared context
2. Build assigned features
3. Write status to shared context

## Current Sprint
- Implement POST /todos endpoint
- Implement GET /todos endpoint
- Add input validation

## File Ownership
You own: src/ scripts/
DEV

    # QA prompt
    cat > "$DEMO_DIR/prompts/09-qa/09-qa.txt" <<'QA'
# QA Engineer

You test everything. Find bugs. Verify quality.

## Tasks
1. Read shared context
2. Run existing tests
3. Write new tests for recent changes
4. Report findings to shared context

## Current Sprint
- Test TODO CRUD endpoints
- Verify input validation
- Check error handling

## File Ownership
You own: tests/
QA

    # Create sample source files
    cat > "$DEMO_DIR/src/server.sh" <<'SRC'
#!/usr/bin/env bash
# TODO API server stub
echo "TODO API running on port 8080"
SRC

    cat > "$DEMO_DIR/tests/test-todo.sh" <<'TST'
#!/usr/bin/env bash
# Test: TODO API
echo "PASS: placeholder test"
exit 0
TST

    # Initial commit
    git -C "$DEMO_DIR" add -A >/dev/null 2>&1
    git -C "$DEMO_DIR" commit -m "Initial project setup" >/dev/null 2>&1

    printf '%s' "$DEMO_DIR"
}

# ── Simulate orchestration cycle ──

_simulate_cycle() {
    local cycle_num="$1" project_dir="$2"

    printf "\n"
    printf "  ${ORANGE}${BOLD}═══ CYCLE %d ═══${RESET}\n" "$cycle_num"
    printf "\n"

    # Pre-cycle
    _info "Validating agents.conf..."
    sleep 0.3
    _ok "3 agents configured (1 coordinator, 2 workers)"

    _info "Checking cycle intervals..."
    sleep 0.2

    local agents_this_cycle=()
    agents_this_cycle+=("06-developer")

    if (( cycle_num % 2 == 0 )); then
        agents_this_cycle+=("09-qa")
    fi

    # Always add PM last
    agents_this_cycle+=("03-pm")

    local active_count=${#agents_this_cycle[@]}
    _ok "$active_count agent(s) active this cycle"

    _divider

    # Run each agent
    for agent_id in "${agents_this_cycle[@]}"; do
        local color label
        case "$agent_id" in
            06-developer) color="$BLUE";    label="Developer" ;;
            09-qa)        color="$YELLOW";  label="QA"        ;;
            03-pm)        color="$MAGENTA"; label="PM"        ;;
            *)            color="$RESET";   label="$agent_id" ;;
        esac

        _agent_log "$label" "$color" "Starting..."
        sleep 0.4

        # Simulate prompt loading
        local prompt_file
        case "$agent_id" in
            06-developer) prompt_file="prompts/06-developer/06-dev.txt" ;;
            09-qa)        prompt_file="prompts/09-qa/09-qa.txt" ;;
            03-pm)        prompt_file="prompts/03-pm/03-pm.txt" ;;
        esac

        local lines
        lines=$(wc -l < "$project_dir/$prompt_file") || lines=0
        local tokens=$(( lines * 4 ))
        _agent_log "$label" "$color" "Loaded prompt: ${lines} lines (~${tokens} tokens)"
        sleep 0.3

        # Simulate work
        case "$agent_id" in
            06-developer)
                _agent_log "$label" "$color" "Reading shared context..."
                sleep 0.3
                if [[ "$cycle_num" -eq 1 ]]; then
                    _agent_log "$label" "$color" "Implementing POST /todos endpoint..."
                    sleep 0.5
                    echo '# POST /todos handler' >> "$project_dir/src/server.sh"
                    _agent_log "$label" "$color" "Implementing GET /todos endpoint..."
                    sleep 0.4
                    echo '# GET /todos handler' >> "$project_dir/src/server.sh"
                    _agent_log "$label" "$color" "${GREEN}2 files changed, 4 insertions${RESET}"
                else
                    _agent_log "$label" "$color" "Adding input validation..."
                    sleep 0.5
                    echo '# Input validation' >> "$project_dir/src/server.sh"
                    _agent_log "$label" "$color" "${GREEN}1 file changed, 2 insertions${RESET}"
                fi
                sleep 0.2
                _agent_log "$label" "$color" "Writing status to shared context..."
                sleep 0.2
                _agent_log "$label" "$color" "${GREEN}Done${RESET} (1.2s)"
                ;;

            09-qa)
                _agent_log "$label" "$color" "Reading shared context..."
                sleep 0.3
                _agent_log "$label" "$color" "Running existing tests..."
                sleep 0.4
                _agent_log "$label" "$color" "${GREEN}1/1 tests pass${RESET}"
                _agent_log "$label" "$color" "Writing test for POST /todos..."
                sleep 0.5
                echo '# Test POST /todos' >> "$project_dir/tests/test-todo.sh"
                _agent_log "$label" "$color" "Writing test for GET /todos..."
                sleep 0.4
                echo '# Test GET /todos' >> "$project_dir/tests/test-todo.sh"
                _agent_log "$label" "$color" "${GREEN}1 file changed, 6 insertions${RESET}"
                _agent_log "$label" "$color" "Verdict: ${GREEN}PASS${RESET} — no issues found"
                sleep 0.2
                _agent_log "$label" "$color" "${GREEN}Done${RESET} (1.8s)"
                ;;

            03-pm)
                _agent_log "$label" "$color" "Reading shared context..."
                sleep 0.3
                _agent_log "$label" "$color" "Reviewing cycle output..."
                sleep 0.4

                if (( cycle_num % 2 == 0 )); then
                    _agent_log "$label" "$color" "Developer: ${GREEN}productive${RESET} | QA: ${GREEN}productive${RESET}"
                else
                    _agent_log "$label" "$color" "Developer: ${GREEN}productive${RESET} | QA: ${DIM}skipped (interval=2)${RESET}"
                fi

                sleep 0.3
                _agent_log "$label" "$color" "Updating prompts for next cycle..."
                sleep 0.3
                _agent_log "$label" "$color" "${GREEN}Done${RESET} (0.9s)"
                ;;
        esac

        # Simulate commit
        sleep 0.2
        git -C "$project_dir" add -A >/dev/null 2>&1
        git -C "$project_dir" commit -m "cycle-${cycle_num}: ${agent_id} work" --allow-empty >/dev/null 2>&1
        _agent_log "$label" "$color" "${DIM}Committed: cycle-${cycle_num}: ${agent_id}${RESET}"

        printf "\n"
    done

    # Post-cycle summary
    local commit_count
    commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null) || commit_count=0
    printf "  ${BOLD}Cycle %d complete${RESET}  " "$cycle_num"
    printf "${GREEN}%d agents${RESET} ran, " "$active_count"
    printf "${GREEN}%d total commits${RESET}\n" "$commit_count"
}

# ── Main ──

main() {
    _parse_args "$@"
    _setup_colors
    _banner

    _step 1 "Creating temporary project..."
    local project_dir
    project_dir="$(_create_temp_project)"
    _ok "Project created at: $project_dir"
    sleep 0.3

    _step 2 "Configuring 3 agents: PM, Developer, QA"
    _info "  03-pm        — PM Coordinator     (interval=0, runs LAST)"
    _info "  06-developer — Full-Stack Dev      (interval=1, every cycle)"
    _info "  09-qa        — QA Engineer         (interval=2, every other cycle)"
    sleep 0.5

    _step 3 "Running $CYCLES orchestration cycle(s)..."
    sleep 0.3

    local i
    for (( i=1; i<=CYCLES; i++ )); do
        _simulate_cycle "$i" "$project_dir"
    done

    _divider

    # Final summary
    printf "  ${ORANGE}${BOLD}DEMO COMPLETE${RESET}\n\n"

    local total_commits
    total_commits=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null) || total_commits=0

    printf "  ${BOLD}Summary:${RESET}\n"
    printf "    Cycles:    %d\n" "$CYCLES"
    printf "    Agents:    3 (PM, Developer, QA)\n"
    printf "    Commits:   %d\n" "$total_commits"
    printf "    API calls: 0 (dry-run simulation)\n"
    printf "\n"
    printf "  ${BOLD}Try it yourself:${RESET}\n"
    printf "    ${CYAN}git clone https://github.com/ChetanSarda99/openOrchyStraw.git${RESET}\n"
    printf "    ${CYAN}cd openOrchyStraw${RESET}\n"
    printf "    ${CYAN}bash scripts/auto-agent.sh orchestrate 3 --dry-run${RESET}\n"
    printf "\n"

    # Cleanup
    rm -rf "$(dirname "$project_dir")"
}

main "$@"
