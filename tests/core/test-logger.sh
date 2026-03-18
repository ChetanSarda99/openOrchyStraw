#!/usr/bin/env bash
# Test: logger.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

source "$PROJECT_ROOT/src/core/logger.sh"

# Test 1: init creates a log file
orch_log_init "$TEST_DIR"
[[ -f "$TEST_DIR/cycle-1.log" ]] || { echo "cycle-1.log not created"; exit 1; }

# Test 2: logging writes to file
ORCH_QUIET=1 orch_log INFO test "hello world"
grep -q "hello world" "$TEST_DIR/cycle-1.log" || { echo "log entry not in file"; exit 1; }

# Test 3: level filtering (DEBUG filtered when min=INFO)
ORCH_LOG_LEVEL=INFO
ORCH_QUIET=1 orch_log DEBUG test "should not appear"
if grep -q "should not appear" "$TEST_DIR/cycle-1.log"; then
    echo "DEBUG message leaked through INFO filter"
    exit 1
fi

# Test 4: summary runs without error
ORCH_QUIET=1 orch_log_summary

# Test 5: log_to_file writes to specific file
ORCH_QUIET=1 orch_log_to_file "$TEST_DIR/custom.log" WARN test "custom warning"
grep -q "custom warning" "$TEST_DIR/custom.log" || { echo "custom log not written"; exit 1; }

echo "logger: all tests passed"
