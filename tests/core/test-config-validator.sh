#!/usr/bin/env bash
# Test: config-validator.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

source "$PROJECT_ROOT/src/core/config-validator.sh"

# Create a valid test config
mkdir -p "$TEST_DIR/prompts"
# Create a prompt file with >30 lines
for i in $(seq 1 35); do echo "line $i" >> "$TEST_DIR/prompts/agent.txt"; done

cat > "$TEST_DIR/agents.conf" <<'EOF'
# Test config
01-test | prompts/agent.txt | src/ | 0 | Test Agent
EOF

# Test 1: valid config passes
if ! orch_validate_config "$TEST_DIR/agents.conf" 2>/dev/null; then
    echo "valid config should pass"
    exit 1
fi

# Test 2: missing file fails
if orch_validate_config "$TEST_DIR/nonexistent.conf" 2>/dev/null; then
    echo "missing file should fail"
    exit 1
fi

# Test 3: bad field count fails
cat > "$TEST_DIR/bad.conf" <<'EOF'
01-test | prompts/agent.txt | src/
EOF
if orch_validate_config "$TEST_DIR/bad.conf" 2>/dev/null; then
    echo "bad field count should fail"
    exit 1
fi

# Test 4: duplicate IDs fail
cat > "$TEST_DIR/dup.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | First
01-test | prompts/agent.txt | src/ | 1 | Second
EOF
if orch_validate_config "$TEST_DIR/dup.conf" 2>/dev/null; then
    echo "duplicate IDs should fail"
    exit 1
fi

# Test 5: error count works
count=$(orch_config_error_count)
[[ "$count" =~ ^[0-9]+$ ]] || { echo "error count not numeric: '$count'"; exit 1; }

# Test 6: v2 format (8 columns) passes validation
cat > "$TEST_DIR/v2.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test | 5 | none | none
EOF
if ! orch_validate_config "$TEST_DIR/v2.conf" 2>/dev/null; then
    echo "v2 config (8 col) should pass"
    exit 1
fi

# Test 7: v2+ format (9 columns with model) passes validation
cat > "$TEST_DIR/v9.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test | 5 | none | none | sonnet
EOF
if ! orch_validate_config "$TEST_DIR/v9.conf" 2>/dev/null; then
    echo "v9 config (9 col) should pass"
    exit 1
fi

# Test 8: unknown model generates warning but does NOT fail
cat > "$TEST_DIR/badmodel.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test | 5 | none | none | gpt-4o
EOF
if ! orch_validate_config "$TEST_DIR/badmodel.conf" 2>/dev/null; then
    echo "unknown model should warn, not fail"
    exit 1
fi
warn_count=$(orch_config_warning_count)
[[ "$warn_count" -ge 1 ]] || { echo "expected warning for unknown model, got $warn_count"; exit 1; }

# Test 9: valid model names don't generate warnings
cat > "$TEST_DIR/goodmodel.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test | 5 | none | none | opus
EOF
orch_validate_config "$TEST_DIR/goodmodel.conf" 2>/dev/null
warn_count=$(orch_config_warning_count)
[[ "$warn_count" -eq 0 ]] || { echo "valid model should not warn, got $warn_count"; exit 1; }

# Test 10: 6 columns (invalid) fails
cat > "$TEST_DIR/bad6.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test | 5
EOF
if orch_validate_config "$TEST_DIR/bad6.conf" 2>/dev/null; then
    echo "6-column config should fail"
    exit 1
fi

echo "config-validator: all tests passed"
