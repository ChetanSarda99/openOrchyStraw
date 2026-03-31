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

# Test 11: v3 format (7 columns: id|prompt|ownership|interval|label|model|max_tokens) passes
cat > "$TEST_DIR/v3.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test Agent | sonnet | 200000
EOF
if ! orch_validate_config "$TEST_DIR/v3.conf" 2>/dev/null; then
    echo "v3 config (7 col) should pass"
    exit 1
fi

# Test 12: v3 with valid model and max_tokens — no warnings
orch_validate_config "$TEST_DIR/v3.conf" 2>/dev/null
warn_count=$(orch_config_warning_count)
[[ "$warn_count" -eq 0 ]] || { echo "v3 valid config should not warn, got $warn_count"; exit 1; }

# Test 13: v3 with unknown model warns but passes
cat > "$TEST_DIR/v3badmodel.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test | gpt-4o | 150000
EOF
if ! orch_validate_config "$TEST_DIR/v3badmodel.conf" 2>/dev/null; then
    echo "v3 unknown model should warn, not fail"
    exit 1
fi
warn_count=$(orch_config_warning_count)
[[ "$warn_count" -ge 1 ]] || { echo "expected warning for unknown model in v3, got $warn_count"; exit 1; }

# Test 14: v3 with non-numeric max_tokens fails
cat > "$TEST_DIR/v3badtokens.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test | opus | abc
EOF
if orch_validate_config "$TEST_DIR/v3badtokens.conf" 2>/dev/null; then
    echo "v3 non-numeric max_tokens should fail"
    exit 1
fi

# Test 15: v3 with max_tokens=0 fails
cat > "$TEST_DIR/v3zero.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test | opus | 0
EOF
if orch_validate_config "$TEST_DIR/v3zero.conf" 2>/dev/null; then
    echo "v3 max_tokens=0 should fail"
    exit 1
fi

# Test 16: v3 with suspiciously low max_tokens warns but passes
cat > "$TEST_DIR/v3low.conf" <<'EOF'
01-test | prompts/agent.txt | src/ | 0 | Test | opus | 5000
EOF
if ! orch_validate_config "$TEST_DIR/v3low.conf" 2>/dev/null; then
    echo "v3 low max_tokens should warn, not fail"
    exit 1
fi
warn_count=$(orch_config_warning_count)
[[ "$warn_count" -ge 1 ]] || { echo "expected warning for low max_tokens, got $warn_count"; exit 1; }

# Test 17: v3 multi-agent with mixed models passes
cat > "$TEST_DIR/v3multi.conf" <<'EOF'
06-backend | prompts/agent.txt | scripts/ src/core/ | 1 | Backend Developer | sonnet | 200000
02-cto     | prompts/agent.txt | docs/architecture/ | 2 | CTO               | opus   | 150000
03-pm      | prompts/agent.txt | prompts/ docs/     | 0 | PM Coordinator    | sonnet | 200000
EOF
if ! orch_validate_config "$TEST_DIR/v3multi.conf" 2>/dev/null; then
    echo "v3 multi-agent config should pass"
    exit 1
fi

echo "config-validator: all tests passed"
