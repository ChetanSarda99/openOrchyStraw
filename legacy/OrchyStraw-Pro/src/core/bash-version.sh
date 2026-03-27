#!/usr/bin/env bash
# =============================================================================
# bash-version.sh — Bash version gate for OrchyStraw
#
# Source this file early (before any bash 4.2+ features are used).
# It will exit with a clear error if bash is too old.
#
# Usage:
#   source src/core/bash-version.sh
#
# Requires: bash 4.2+
#   - associative arrays (declare -A) need bash 4.0+
#   - ${var^^} uppercase expansion needs bash 4.0+
#   - declare -gA (global scope) needs bash 4.2+
#   - We audited all src/core/ modules — 4.2 is the true minimum
#   - macOS ships bash 3.2 (GPLv2); brew install bash gives 5.x
#
# Changelog:
#   v0.2.0 — Lowered from 5.0 to 4.2 (#65 macOS compatibility)
#             No module uses declare -n (4.3+) or bash 5.x features
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_BASH_VERSION_LOADED:-}" ]] && return 0
readonly _ORCH_BASH_VERSION_LOADED=1

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

readonly _ORCH_BASH_MIN_MAJOR=4
readonly _ORCH_BASH_MIN_MINOR=2

# ---------------------------------------------------------------------------
# orch_check_bash_version
#
# Validates that the running bash version meets the minimum requirement.
# Prints a diagnostic message and returns 1 if the version is too old.
# Returns 0 if the version is acceptable.
#
# When sourced at the top level of a script, a failing check will cause the
# script to exit (because `return 1` at source-time propagates).
# ---------------------------------------------------------------------------
orch_check_bash_version() {
    local current_major="${BASH_VERSINFO[0]:-0}"
    local current_minor="${BASH_VERSINFO[1]:-0}"
    local current_version="${BASH_VERSION:-unknown}"

    if (( current_major > _ORCH_BASH_MIN_MAJOR )); then
        return 0
    fi

    if (( current_major == _ORCH_BASH_MIN_MAJOR && current_minor >= _ORCH_BASH_MIN_MINOR )); then
        return 0
    fi

    cat >&2 <<EOF
[orchystraw] FATAL: bash ${_ORCH_BASH_MIN_MAJOR}.${_ORCH_BASH_MIN_MINOR}+ required, found ${current_version}

OrchyStraw uses bash 4.2+ features (associative arrays, declare -gA,
uppercase expansion). macOS ships bash 3.2 by default.

Fix:
  brew install bash          # macOS — installs to /opt/homebrew/bin/bash
  sudo apt install bash      # Debian/Ubuntu
  sudo dnf install bash      # Fedora/RHEL

After installing, either:
  1. Add to PATH:  export PATH="/opt/homebrew/bin:\$PATH"
  2. Or run directly:  /opt/homebrew/bin/bash scripts/auto-agent.sh orchestrate
  3. Or change default shell:  sudo chsh -s /opt/homebrew/bin/bash
EOF
    return 1
}

# Run the check immediately on source
orch_check_bash_version || exit 1
