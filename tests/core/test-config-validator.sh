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

# --- New tests for upgraded features ---

# Test 18: validate_field — string type
err=$(orch_validate_field "hello" "string") || { echo "valid string should pass"; exit 1; }
err=$(orch_validate_field "" "string" 2>/dev/null) && { echo "empty string should fail"; exit 1; }

# Test 19: validate_field — integer type
orch_validate_field "42" "integer" > /dev/null || { echo "valid integer should pass"; exit 1; }
orch_validate_field "-5" "integer" > /dev/null || { echo "negative integer should pass"; exit 1; }
if orch_validate_field "abc" "integer" > /dev/null 2>&1; then
    echo "non-numeric should fail integer check"
    exit 1
fi

# Test 20: validate_field — integer with range constraint
orch_validate_field "5" "integer" "0:10" > /dev/null || { echo "5 should be in range 0:10"; exit 1; }
if orch_validate_field "15" "integer" "0:10" > /dev/null 2>&1; then
    echo "15 should fail range 0:10"
    exit 1
fi

# Test 21: validate_field — boolean type
orch_validate_field "true" "boolean" > /dev/null || { echo "'true' should be valid boolean"; exit 1; }
orch_validate_field "yes" "boolean" > /dev/null || { echo "'yes' should be valid boolean"; exit 1; }
orch_validate_field "0" "boolean" > /dev/null || { echo "'0' should be valid boolean"; exit 1; }
if orch_validate_field "maybe" "boolean" > /dev/null 2>&1; then
    echo "'maybe' should fail boolean check"
    exit 1
fi

# Test 22: validate_field — enum type
orch_validate_field "opus" "enum" "opus,sonnet,haiku" > /dev/null || { echo "'opus' should be valid enum"; exit 1; }
if orch_validate_field "gpt4" "enum" "opus,sonnet,haiku" > /dev/null 2>&1; then
    echo "'gpt4' should fail enum check"
    exit 1
fi

# Test 23: validate_field — path type
orch_validate_field "/tmp" "path" "exists" > /dev/null || { echo "/tmp should exist"; exit 1; }
if orch_validate_field "/nonexistent/path" "path" "exists" > /dev/null 2>&1; then
    echo "nonexistent path should fail exists check"
    exit 1
fi

# Test 24: validate_field — float type
orch_validate_field "3.14" "float" > /dev/null || { echo "3.14 should be valid float"; exit 1; }
orch_validate_field "42" "float" > /dev/null || { echo "42 should be valid float"; exit 1; }
if orch_validate_field "abc" "float" > /dev/null 2>&1; then
    echo "'abc' should fail float check"
    exit 1
fi

# Test 25: validate_field — string with length constraint
orch_validate_field "hello" "string" "1:10" > /dev/null || { echo "'hello' should pass 1:10 length"; exit 1; }
if orch_validate_field "hi" "string" "5:10" > /dev/null 2>&1; then
    echo "'hi' should fail 5:10 length constraint"
    exit 1
fi

# Test 26: schema validation
cat > "$TEST_DIR/test.schema" <<'EOF'
# field_index | field_name | type | required | default | constraint
0 | id | string | yes | - | -
1 | prompt | string | yes | - | -
2 | interval | integer | yes | - | 0:100
3 | label | string | yes | - | -
EOF

cat > "$TEST_DIR/schema-test.conf" <<'EOF'
agent-1 | prompt.txt | 5 | Backend
agent-2 | prompt.txt | 10 | Frontend
EOF
if ! orch_validate_schema "$TEST_DIR/schema-test.conf" "$TEST_DIR/test.schema" 2>/dev/null; then
    echo "valid schema config should pass"
    exit 1
fi

# Test 27: schema validation — integer out of range
cat > "$TEST_DIR/schema-bad.conf" <<'EOF'
agent-1 | prompt.txt | 200 | Backend
EOF
if orch_validate_schema "$TEST_DIR/schema-bad.conf" "$TEST_DIR/test.schema" 2>/dev/null; then
    echo "integer out of range should fail schema validation"
    exit 1
fi

# Test 28: schema validation — missing required field
cat > "$TEST_DIR/schema-missing.conf" <<'EOF'
 | prompt.txt | 5 | Backend
EOF
if orch_validate_schema "$TEST_DIR/schema-missing.conf" "$TEST_DIR/test.schema" 2>/dev/null; then
    echo "missing required field should fail schema validation"
    exit 1
fi

# Test 29: config defaults
cat > "$TEST_DIR/defaults.txt" <<'EOF'
# field_index | default_value
2 | 1
3 | Default Label
EOF

cat > "$TEST_DIR/defaults-test.conf" <<'EOF'
agent-1 | prompt.txt |  | Backend
agent-2 | prompt.txt | 5 |
EOF
output=$(orch_config_defaults "$TEST_DIR/defaults-test.conf" "$TEST_DIR/defaults.txt")
echo "$output" | grep -q "agent-1" || { echo "defaults output should contain agent-1"; exit 1; }
# The empty interval should get default value 1
echo "$output" | head -1 | grep -q "1" || { echo "empty interval should get default 1"; exit 1; }
# The empty label should get Default Label
echo "$output" | tail -1 | grep -q "Default Label" || { echo "empty label should get default"; exit 1; }

# Test 30: config_get
cat > "$TEST_DIR/get-test.conf" <<'EOF'
# comment
agent-1 | prompt1.txt | src/ | 0 | Backend
agent-2 | prompt2.txt | docs/ | 1 | Frontend
EOF
val=$(orch_config_get "$TEST_DIR/get-test.conf" "agent-1" 1)
[[ "$val" == "prompt1.txt" ]] || { echo "config_get should return 'prompt1.txt', got '$val'"; exit 1; }
val=$(orch_config_get "$TEST_DIR/get-test.conf" "agent-2" 4)
[[ "$val" == "Frontend" ]] || { echo "config_get should return 'Frontend', got '$val'"; exit 1; }
if orch_config_get "$TEST_DIR/get-test.conf" "nonexistent" 0 2>/dev/null; then
    echo "config_get for missing agent should fail"
    exit 1
fi

echo "config-validator: all tests passed"
