#!/usr/bin/env bash
# migrate.sh — OrchyStraw version detection and migration helper
# Usage: migrate.sh {detect|check|upgrade|--help}
set -euo pipefail

# ── Double-source guard ──
[[ -n "${_ORCH_MIGRATE_LOADED:-}" ]] && return 0 2>/dev/null || true
export _ORCH_MIGRATE_LOADED=1

# ── Resolve project root ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${ORCH_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# ── Constants ──
VERSION_FILE="$PROJECT_ROOT/.orchystraw/version"
ORCHYSTRAW_DIR="$PROJECT_ROOT/.orchystraw"

# ── Helpers ──
_log()  { printf '[migrate] %s\n' "$*"; }
_warn() { printf '[migrate] WARNING: %s\n' "$*" >&2; }
_err()  { printf '[migrate] ERROR: %s\n' "$*" >&2; return 1; }

_usage() {
    cat <<'USAGE'
Usage: migrate.sh <command>

Commands:
  detect    Show the detected current version
  check     Dry-run: show what upgrade would do (no changes)
  upgrade   Apply the next version upgrade
  --help    Show this help message

Environment:
  ORCH_PROJECT_ROOT   Override project root (default: parent of scripts/)
USAGE
}

# ── Version detection ──
# Returns a version string: 0.1, 0.2, 0.5, 1.0, or unknown
_detect_version() {
    # Explicit version file takes priority
    if [[ -f "$VERSION_FILE" ]]; then
        local ver
        ver="$(< "$VERSION_FILE")"
        # Validate format: digits.digits.digits
        if [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            # Extract major.minor
            local major_minor="${ver%.*}"
            case "$major_minor" in
                0.1) echo "0.1"; return 0 ;;
                0.2) echo "0.2"; return 0 ;;
                0.5) echo "0.5"; return 0 ;;
                1.0) echo "1.0"; return 0 ;;
                *)   echo "$major_minor"; return 0 ;;
            esac
        fi
    fi

    # Heuristic detection by directory structure
    # v1.0.x: has src-tauri/ with built artifacts
    if [[ -d "$PROJECT_ROOT/src-tauri" ]] && \
       compgen -G "$PROJECT_ROOT/src-tauri/target/release/*" >/dev/null 2>&1; then
        echo "1.0"
        return 0
    fi

    # v0.5.x: has .orchystraw/db/ (SQLite)
    if [[ -d "$ORCHYSTRAW_DIR/db" ]]; then
        echo "0.5"
        return 0
    fi

    # v0.2.x vs v0.1.x: count modules in src/core/
    if [[ -d "$PROJECT_ROOT/src/core" ]]; then
        local module_count
        module_count=$(find "$PROJECT_ROOT/src/core" -maxdepth 1 -name '*.sh' -type f 2>/dev/null | wc -l)
        if [[ "$module_count" -gt 10 ]]; then
            echo "0.2"
            return 0
        elif [[ "$module_count" -ge 1 ]]; then
            echo "0.1"
            return 0
        fi
    fi

    echo "unknown"
    return 0
}

# ── Full version string (for display) ──
_detect_full_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        local ver
        ver="$(< "$VERSION_FILE")"
        if [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ver"
            return 0
        fi
    fi
    local mm
    mm="$(_detect_version)"
    case "$mm" in
        0.1) echo "0.1.0 (inferred)" ;;
        0.2) echo "0.2.0 (inferred)" ;;
        0.5) echo "0.5.0 (inferred)" ;;
        1.0) echo "1.0.0 (inferred)" ;;
        *)   echo "unknown" ;;
    esac
}

# ── Upgrade: v0.1 → v0.2 ──
_upgrade_0_1_to_0_2() {
    local dry_run="${1:-false}"
    local changes=0

    _log "Upgrade path: v0.1.x → v0.2.0"
    echo ""

    # Step 1: Create .orchystraw/ directory
    if [[ ! -d "$ORCHYSTRAW_DIR" ]]; then
        _log "  [1/4] Create $ORCHYSTRAW_DIR/"
        if [[ "$dry_run" == "false" ]]; then
            mkdir -p "$ORCHYSTRAW_DIR"
        fi
        changes=$((changes + 1))
    else
        _log "  [1/4] $ORCHYSTRAW_DIR/ already exists (skip)"
    fi

    # Step 2: Write version file
    if [[ ! -f "$VERSION_FILE" ]]; then
        _log "  [2/4] Write version file (0.2.0)"
        if [[ "$dry_run" == "false" ]]; then
            echo "0.2.0" > "$VERSION_FILE"
        fi
        changes=$((changes + 1))
    else
        _log "  [2/4] Version file already exists (skip)"
    fi

    # Step 3: Verify new modules exist
    local required_modules=(
        "config-validator.sh"
        "cycle-state.sh"
        "dynamic-router.sh"
        "error-handler.sh"
        "issue-tracker.sh"
        "knowledge-base.sh"
        "model-registry.sh"
        "prompt-compression.sh"
    )
    local missing=()
    for mod in "${required_modules[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/src/core/$mod" ]]; then
            missing+=("$mod")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        _warn "  [3/4] Missing v0.2 modules: ${missing[*]}"
        _warn "        These modules are expected in src/core/"
        changes=$((changes + 1))
    else
        _log "  [3/4] All required v0.2 modules present"
    fi

    # Step 4: Check agents.conf for v0.2 format
    local agents_conf="$PROJECT_ROOT/agents.conf"
    if [[ -f "$agents_conf" ]]; then
        if ! grep -q 'model_routing' "$agents_conf" 2>/dev/null; then
            _warn "  [4/4] agents.conf may need updates for v0.2"
            _warn "        v0.2 expects: model_routing, conditional_activation fields"
            changes=$((changes + 1))
        else
            _log "  [4/4] agents.conf appears v0.2-compatible"
        fi
    else
        _warn "  [4/4] agents.conf not found — create one from agents.conf.example"
        changes=$((changes + 1))
    fi

    echo ""
    if [[ "$dry_run" == "true" ]]; then
        _log "Dry run complete. $changes change(s) would be applied."
    else
        _log "Upgrade complete. $changes change(s) applied."
    fi
    return 0
}

# ── Command: detect ──
cmd_detect() {
    local full_ver
    full_ver="$(_detect_full_version)"
    _log "Detected version: $full_ver"
    _log "Project root: $PROJECT_ROOT"

    # Extra context
    if [[ -d "$PROJECT_ROOT/src/core" ]]; then
        local count
        count=$(find "$PROJECT_ROOT/src/core" -maxdepth 1 -name '*.sh' -type f 2>/dev/null | wc -l)
        _log "Core modules: $count"
    fi
    [[ -d "$ORCHYSTRAW_DIR" ]] && _log ".orchystraw/ directory: exists" || _log ".orchystraw/ directory: missing"
}

# ── Command: check (dry-run) ──
cmd_check() {
    local current
    current="$(_detect_version)"

    case "$current" in
        0.1)
            _log "Current: v0.1.x — upgrade to v0.2.0 available"
            echo ""
            _upgrade_0_1_to_0_2 "true"
            ;;
        0.2)
            _log "Current: v0.2.x — no upgrade path available yet (v0.5 planned)"
            ;;
        0.5)
            _log "Current: v0.5.x — no upgrade path available yet (v1.0 planned)"
            ;;
        1.0)
            _log "Current: v1.0.x — latest version"
            ;;
        *)
            _err "Cannot determine current version. Run 'migrate.sh detect' for details."
            ;;
    esac
}

# ── Command: upgrade ──
cmd_upgrade() {
    local current
    current="$(_detect_version)"

    case "$current" in
        0.1)
            _log "Upgrading from v0.1.x to v0.2.0..."
            echo ""
            _upgrade_0_1_to_0_2 "false"
            ;;
        0.2)
            _log "Already at v0.2.x. No upgrade path available yet."
            _log "Next version (v0.5) is not yet implemented."
            ;;
        0.5)
            _log "Already at v0.5.x. No upgrade path available yet."
            _log "Next version (v1.0) is not yet implemented."
            ;;
        1.0)
            _log "Already at v1.0.x (latest). Nothing to upgrade."
            ;;
        *)
            _err "Cannot determine current version. Run 'migrate.sh detect' for details."
            ;;
    esac
}

# ── Main ──
main() {
    if [[ $# -eq 0 ]]; then
        _usage
        exit 1
    fi

    case "$1" in
        detect)   cmd_detect ;;
        check)    cmd_check ;;
        upgrade)  cmd_upgrade ;;
        --help|-h) _usage ;;
        *)
            _err "Unknown command: $1"
            _usage
            exit 1
            ;;
    esac
}

# Run main only when executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
