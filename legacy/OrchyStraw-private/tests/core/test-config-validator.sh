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

echo "config-validator: all tests passed"
