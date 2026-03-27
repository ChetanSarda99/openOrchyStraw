#!/usr/bin/env bash
# =============================================================================
# bash-version.sh — Bash version gate for OrchyStraw
#
# Source this file early (before any bash 5.x features are used).
# It will exit with a clear error if bash is too old.
#
# Usage:
#   source src/core/bash-version.sh
#
# Requires: bash 5.0+
#   - associative arrays (declare -A) need bash 4.0+
#   - ${var^^} uppercase expansion needs bash 4.0+
#   - declare -gA (global scope) needs bash 4.2+
#   - nameref (declare -n) needs bash 4.3+
#   - We require 5.0+ for consistency and to avoid subtle 4.x edge cases
# =============================================================================

# Guard against double-sourcing
[[ -n "${_ORCH_BASH_VERSION_LOADED:-}" ]] && return 0
readonly _ORCH_BASH_VERSION_LOADED=1

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

readonly _ORCH_BASH_MIN_MAJOR=5
readonly _ORCH_BASH_MIN_MINOR=0

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

OrchyStraw uses bash 5.x features (associative arrays with declare -gA,
uppercase expansion, namerefs). macOS ships bash 3.2 by default.

Fix:
  brew install bash          # macOS — installs to /opt/homebrew/bin/bash
  sudo apt install bash      # Debian/Ubuntu
  sudo dnf install bash      # Fedora/RHEL

Then re-run with the updated bash, or add it to your PATH.
EOF
    return 1
}

# Run the check immediately on source
orch_check_bash_version || exit 1
