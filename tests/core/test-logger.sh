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

# --- New tests for upgraded features ---

# Test 6: JSON structured logging
_ORCH_LOGGER_LOADED=""
_ORCH_LOG_FILE=""
_ORCH_LOG_COUNTS=( [DEBUG]=0 [INFO]=0 [WARN]=0 [ERROR]=0 [FATAL]=0 )
ORCH_LOG_FORMAT=json
source "$PROJECT_ROOT/src/core/logger.sh"
orch_log_init "$TEST_DIR/json-logs"
ORCH_QUIET=1 orch_log INFO test-json "JSON message test"
# Verify the log file contains valid JSON-like structure
grep -q '"level":"INFO"' "$TEST_DIR/json-logs/cycle-1.log" || { echo "JSON format not in log file"; exit 1; }
grep -q '"message":"JSON message test"' "$TEST_DIR/json-logs/cycle-1.log" || { echo "JSON message not found"; exit 1; }

# Test 7: JSON escape special characters
ORCH_QUIET=1 orch_log INFO test-json 'Message with "quotes" and
newline'
grep -q '\\n' "$TEST_DIR/json-logs/cycle-1.log" || { echo "JSON escape for newline failed"; exit 1; }
grep -q '\\"quotes\\"' "$TEST_DIR/json-logs/cycle-1.log" || { echo "JSON escape for quotes failed"; exit 1; }

# Test 8: orch_log_json with extra fields
ORCH_QUIET=1 orch_log_json INFO test-json "Extra fields test" '"agent_id":"06-backend","exit_code":0'
grep -q '"agent_id":"06-backend"' "$TEST_DIR/json-logs/cycle-1.log" || { echo "Extra JSON fields not found"; exit 1; }

# Test 9: JSON summary
output=$(ORCH_QUIET=0 orch_log_summary)
echo "$output" | grep -q '"event":"summary"' || { echo "JSON summary format failed"; exit 1; }

# Reset to text mode for remaining tests
ORCH_LOG_FORMAT=text

# Test 10: Log rotation
_ORCH_LOGGER_LOADED=""
_ORCH_LOG_FILE=""
_ORCH_LOG_COUNTS=( [DEBUG]=0 [INFO]=0 [WARN]=0 [ERROR]=0 [FATAL]=0 )
source "$PROJECT_ROOT/src/core/logger.sh"
ORCH_LOG_MAX_SIZE=100  # Very small to trigger rotation
ORCH_LOG_FORMAT=text
ROT_DIR="$TEST_DIR/rotation"
mkdir -p "$ROT_DIR"
# Create a file larger than 100 bytes
printf '%0200d' 0 > "$ROT_DIR/test.log"
_orch_rotate_log "$ROT_DIR/test.log"
[[ -f "$ROT_DIR/test.log.1" ]] || { echo "Log rotation did not create .1 file"; exit 1; }
[[ -f "$ROT_DIR/test.log" ]] || { echo "Log rotation did not create new empty file"; exit 1; }
new_size=$(wc -c < "$ROT_DIR/test.log")
new_size="${new_size//[[:space:]]/}"
[[ "$new_size" -eq 0 ]] || { echo "Rotated log should be empty, got $new_size bytes"; exit 1; }

# Test 11: Log rotation respects max files
ORCH_LOG_MAX_FILES=2
printf '%0200d' 0 > "$ROT_DIR/test2.log"
_orch_rotate_log "$ROT_DIR/test2.log"
printf '%0200d' 0 > "$ROT_DIR/test2.log"
_orch_rotate_log "$ROT_DIR/test2.log"
printf '%0200d' 0 > "$ROT_DIR/test2.log"
_orch_rotate_log "$ROT_DIR/test2.log"
[[ ! -f "$ROT_DIR/test2.log.3" ]] || { echo "Rotation should not exceed max_files=2"; exit 1; }
ORCH_LOG_MAX_SIZE=10485760
ORCH_LOG_MAX_FILES=5

# Test 12: Color detection — never mode
ORCH_LOG_COLOR=never
_ORCH_COLOR_SUPPORTED=""
_orch_detect_color
[[ "$_ORCH_COLOR_SUPPORTED" == "0" ]] || { echo "Color should be disabled in 'never' mode"; exit 1; }

# Test 13: Color detection — always mode
ORCH_LOG_COLOR=always
_ORCH_COLOR_SUPPORTED=""
_orch_detect_color
[[ "$_ORCH_COLOR_SUPPORTED" == "1" ]] || { echo "Color should be enabled in 'always' mode"; exit 1; }

# Test 14: orch_log_color_supported function
ORCH_LOG_COLOR=always
_ORCH_COLOR_SUPPORTED=""
orch_log_color_supported || { echo "color_supported should return 0 in always mode"; exit 1; }

# Test 15: NO_COLOR environment variable respected
ORCH_LOG_COLOR=auto
_ORCH_COLOR_SUPPORTED=""
NO_COLOR=1
_orch_detect_color
[[ "$_ORCH_COLOR_SUPPORTED" == "0" ]] || { echo "NO_COLOR should disable colors"; exit 1; }
unset NO_COLOR

# Reset
ORCH_LOG_COLOR=auto
_ORCH_COLOR_SUPPORTED=""

echo "logger: all tests passed"
