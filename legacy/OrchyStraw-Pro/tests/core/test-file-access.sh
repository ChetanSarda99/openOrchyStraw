#!/usr/bin/env bash
# Test: file-access.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

source "$PROJECT_ROOT/src/core/file-access.sh"

echo "=== file-access.sh tests ==="

# --- 1. Module loads (guard var set) ---
if [[ "${_ORCH_FILE_ACCESS_LOADED:-}" == "1" ]]; then
    pass "1. module loads — guard var set"
else
    fail "1. module loads — guard var set"
fi

# --- 2. Double-source guard ---
# Sourcing again should be a no-op (return 0, not error)
if source "$PROJECT_ROOT/src/core/file-access.sh" 2>/dev/null; then
    pass "2. double-source guard — no error on re-source"
else
    fail "2. double-source guard — no error on re-source"
fi

# --- 3. orch_access_init sets root and defaults ---
orch_access_init "$TMPDIR_TEST"
if [[ "$_ORCH_ACCESS_ROOT" == "$TMPDIR_TEST" ]]; then
    pass "3. orch_access_init sets root"
else
    fail "3. orch_access_init sets root (got: $_ORCH_ACCESS_ROOT)"
fi

# --- 4. Default protected paths populated ---
if [[ "${#_ORCH_ACCESS_PROTECTED[@]}" -gt 0 ]]; then
    pass "4. default protected paths populated (${#_ORCH_ACCESS_PROTECTED[@]} entries)"
else
    fail "4. default protected paths populated"
fi

# --- 5. Default shared paths populated ---
if [[ "${#_ORCH_ACCESS_SHARED[@]}" -gt 0 ]]; then
    pass "5. default shared paths populated (${#_ORCH_ACCESS_SHARED[@]} entries)"
else
    fail "5. default shared paths populated"
fi

# --- 6. orch_access_set_protected replaces paths ---
orch_access_set_protected "foo/ bar/"
if [[ "${#_ORCH_ACCESS_PROTECTED[@]}" -eq 2 ]] \
   && [[ "${_ORCH_ACCESS_PROTECTED[0]}" == "foo/" ]] \
   && [[ "${_ORCH_ACCESS_PROTECTED[1]}" == "bar/" ]]; then
    pass "6. orch_access_set_protected replaces paths"
else
    fail "6. orch_access_set_protected replaces paths (got: ${_ORCH_ACCESS_PROTECTED[*]})"
fi
# Restore defaults for later tests
orch_access_init "$TMPDIR_TEST"

# --- 7. orch_access_set_shared replaces paths ---
orch_access_set_shared "shared-a/ shared-b/"
if [[ "${#_ORCH_ACCESS_SHARED[@]}" -eq 2 ]] \
   && [[ "${_ORCH_ACCESS_SHARED[0]}" == "shared-a/" ]] \
   && [[ "${_ORCH_ACCESS_SHARED[1]}" == "shared-b/" ]]; then
    pass "7. orch_access_set_shared replaces paths"
else
    fail "7. orch_access_set_shared replaces paths (got: ${_ORCH_ACCESS_SHARED[*]})"
fi
# Restore defaults
orch_access_init "$TMPDIR_TEST"

# --- 8. orch_access_register_ownership stores owned paths ---
orch_access_register_ownership "06-backend" "src/core/ scripts/helpers/"
if [[ "${_ORCH_ACCESS_OWNERSHIP[06-backend]}" == "src/core/ scripts/helpers/" ]]; then
    pass "8. register_ownership stores owned paths"
else
    fail "8. register_ownership stores owned paths (got: ${_ORCH_ACCESS_OWNERSHIP[06-backend]:-EMPTY})"
fi

# --- 9. orch_access_register_ownership handles exclusions (! prefix) ---
orch_access_register_ownership "11-web" "site/ !site/secret/"
if [[ "${_ORCH_ACCESS_EXCLUSIONS[11-web]}" == "site/secret/" ]]; then
    pass "9. register_ownership handles exclusions"
else
    fail "9. register_ownership handles exclusions (got: ${_ORCH_ACCESS_EXCLUSIONS[11-web]:-EMPTY})"
fi

# --- 10. orch_access_register_ownership deduplicates agent list ---
orch_access_register_ownership "06-backend" "src/core/"
orch_access_register_ownership "06-backend" "src/core/ src/lib/"
local_count=0
for a in "${_ORCH_ACCESS_ALL_AGENTS[@]}"; do
    [[ "$a" == "06-backend" ]] && (( local_count++ )) || true
done
if [[ "$local_count" -eq 1 ]]; then
    pass "10. register_ownership deduplicates agent list"
else
    fail "10. register_ownership deduplicates agent list (count=$local_count)"
fi

# --- 11. orch_access_check returns "protected:denied" for protected files ---
result=$(orch_access_check "06-backend" "scripts/auto-agent.sh")
if [[ "$result" == "protected:denied" ]]; then
    pass "11. check returns protected:denied"
else
    fail "11. check returns protected:denied (got: $result)"
fi

# --- 12. orch_access_check returns "owned:read-write" for owned files ---
result=$(orch_access_check "06-backend" "src/core/foo.sh")
if [[ "$result" == "owned:read-write" ]]; then
    pass "12. check returns owned:read-write"
else
    fail "12. check returns owned:read-write (got: $result)"
fi

# --- 13. orch_access_check returns "shared:read-write" for shared files ---
result=$(orch_access_check "06-backend" "prompts/00-shared-context/context.md")
if [[ "$result" == "shared:read-write" ]]; then
    pass "13. check returns shared:read-write"
else
    fail "13. check returns shared:read-write (got: $result)"
fi

# --- 14. orch_access_check returns "unowned:read-only" for another agent's files ---
result=$(orch_access_check "06-backend" "site/index.html")
if [[ "$result" == "unowned:read-only" ]]; then
    pass "14. check returns unowned:read-only"
else
    fail "14. check returns unowned:read-only (got: $result)"
fi

# --- 15. orch_access_check returns "unknown:read-only" for unregistered files ---
result=$(orch_access_check "06-backend" "random/unregistered/file.txt")
if [[ "$result" == "unknown:read-only" ]]; then
    pass "15. check returns unknown:read-only"
else
    fail "15. check returns unknown:read-only (got: $result)"
fi

# --- 16. orch_access_can_write returns 0 for owned files ---
if orch_access_can_write "06-backend" "src/core/foo.sh"; then
    pass "16. can_write returns 0 for owned"
else
    fail "16. can_write returns 0 for owned"
fi

# --- 17. orch_access_can_write returns 1 for protected files ---
if ! orch_access_can_write "06-backend" "scripts/auto-agent.sh"; then
    pass "17. can_write returns 1 for protected"
else
    fail "17. can_write returns 1 for protected"
fi

# --- 18. orch_access_can_write returns 1 for unowned files ---
if ! orch_access_can_write "06-backend" "site/index.html"; then
    pass "18. can_write returns 1 for unowned"
else
    fail "18. can_write returns 1 for unowned"
fi

# --- 19. orch_access_can_read returns 0 for owned/shared/unowned ---
ok=true
orch_access_can_read "06-backend" "src/core/foo.sh" || ok=false
orch_access_can_read "06-backend" "prompts/00-shared-context/context.md" || ok=false
orch_access_can_read "06-backend" "site/index.html" || ok=false
if $ok; then
    pass "19. can_read returns 0 for owned/shared/unowned"
else
    fail "19. can_read returns 0 for owned/shared/unowned"
fi

# --- 20. orch_access_can_read returns 1 for protected (non-orchestrator) ---
if ! orch_access_can_read "06-backend" "scripts/auto-agent.sh"; then
    pass "20. can_read returns 1 for protected (non-orchestrator)"
else
    fail "20. can_read returns 1 for protected (non-orchestrator)"
fi

# --- 21. orch_access_can_read returns 0 for protected when agent is "orchestrator" ---
if orch_access_can_read "orchestrator" "scripts/auto-agent.sh"; then
    pass "21. can_read returns 0 for protected when orchestrator"
else
    fail "21. can_read returns 0 for protected when orchestrator"
fi

# --- 22. orch_access_validate_writes returns 0 when all writable ---
if orch_access_validate_writes "06-backend" "src/core/foo.sh src/core/bar.sh" 2>/dev/null; then
    pass "22. validate_writes returns 0 when all writable"
else
    fail "22. validate_writes returns 0 when all writable"
fi

# --- 23. orch_access_validate_writes returns 1 when any violation ---
if ! orch_access_validate_writes "06-backend" "src/core/foo.sh scripts/auto-agent.sh" 2>/dev/null; then
    pass "23. validate_writes returns 1 when any violation"
else
    fail "23. validate_writes returns 1 when any violation"
fi

# --- 24. orch_access_zone_for returns correct zone names ---
z_protected=$(orch_access_zone_for "scripts/auto-agent.sh")
z_shared=$(orch_access_zone_for "prompts/00-shared-context/context.md")
z_owned=$(orch_access_zone_for "src/core/foo.sh")
z_unknown=$(orch_access_zone_for "random/nowhere.txt")
if [[ "$z_protected" == "protected" ]] \
   && [[ "$z_shared" == "shared" ]] \
   && [[ "$z_owned" == "owned" ]] \
   && [[ "$z_unknown" == "unknown" ]]; then
    pass "24. zone_for returns correct zone names"
else
    fail "24. zone_for returns correct zone names (got: $z_protected, $z_shared, $z_owned, $z_unknown)"
fi

# --- 25. orch_access_parse_config reads a mock agents.conf ---
cat > "$TMPDIR_TEST/agents.conf" <<'EOF'
# comment line
01-ceo | prompts/01-ceo/01-ceo.txt | docs/strategy/ | 3 | CEO
06-backend | prompts/06-backend/06-backend.txt | src/core/ scripts/helpers/ !scripts/auto-agent.sh | 0 | Backend

EOF

# Re-init to clear previous registrations
orch_access_init "$TMPDIR_TEST"
orch_access_parse_config "$TMPDIR_TEST/agents.conf"

if [[ -n "${_ORCH_ACCESS_OWNERSHIP[01-ceo]:-}" ]] \
   && [[ -n "${_ORCH_ACCESS_OWNERSHIP[06-backend]:-}" ]] \
   && [[ "${_ORCH_ACCESS_EXCLUSIONS[06-backend]}" == "scripts/auto-agent.sh" ]]; then
    pass "25. parse_config reads mock agents.conf"
else
    fail "25. parse_config reads mock agents.conf (ceo=${_ORCH_ACCESS_OWNERSHIP[01-ceo]:-EMPTY}, backend=${_ORCH_ACCESS_OWNERSHIP[06-backend]:-EMPTY}, excl=${_ORCH_ACCESS_EXCLUSIONS[06-backend]:-EMPTY})"
fi

# --- 26. orch_access_report runs without error ---
report_out=$(orch_access_report 2>&1)
if [[ $? -eq 0 ]] && [[ -n "$report_out" ]]; then
    pass "26. orch_access_report runs without error"
else
    fail "26. orch_access_report runs without error"
fi

# --- 27. Path normalization handles ./ prefix ---
result=$(orch_access_check "06-backend" "./src/core/foo.sh")
if [[ "$result" == "owned:read-write" ]]; then
    pass "27. path normalization handles ./ prefix"
else
    fail "27. path normalization handles ./ prefix (got: $result)"
fi

# --- 28. Exclusion paths block ownership match ---
# 06-backend owns src/core/ but has exclusion scripts/auto-agent.sh from parse_config
# Register a clearer test: agent owns broad dir but excludes a subdir
orch_access_init "$TMPDIR_TEST"
orch_access_register_ownership "test-agent" "src/ !src/vendor/"
result=$(orch_access_check "test-agent" "src/vendor/lib.js")
if [[ "$result" != "owned:read-write" ]]; then
    pass "28. exclusion paths block ownership match"
else
    fail "28. exclusion paths block ownership match (got: $result)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
