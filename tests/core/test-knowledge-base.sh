#!/usr/bin/env bash
# Test: knowledge-base.sh — Cross-project knowledge persistence module
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Test harness ──
PASS=0
FAIL=0

_assert() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (expected=%s actual=%s)\n' "$desc" "$expected" "$actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_match() {
    local desc="$1" pattern="$2" actual="$3"
    if echo "$actual" | grep -qE "$pattern"; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (pattern=%s actual=%s)\n' "$desc" "$pattern" "$actual"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -f "$path" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (file not found: %s)\n' "$desc" "$path"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_file_not_exists() {
    local desc="$1" path="$2"
    if [[ ! -f "$path" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (file should not exist: %s)\n' "$desc" "$path"
        FAIL=$(( FAIL + 1 ))
    fi
}

_assert_dir_exists() {
    local desc="$1" path="$2"
    if [[ -d "$path" ]]; then
        printf '  PASS: %s\n' "$desc"
        PASS=$(( PASS + 1 ))
    else
        printf '  FAIL: %s (dir not found: %s)\n' "$desc" "$path"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ── Setup: use a temp directory for isolation ──
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

export ORCHYSTRAW_HOME="$TEST_TMP/orchystraw-home"

# ── Syntax check ──
echo "=== test-knowledge-base.sh ==="
echo ""
echo "--- syntax check ---"
bash -n "$PROJECT_ROOT/src/core/knowledge-base.sh"
_assert "bash -n syntax check passes" "0" "$?"

# ── Source the module ──
source "$PROJECT_ROOT/src/core/knowledge-base.sh"

# ────────────────────────────────────────────
# Group 1: Initialization
# ────────────────────────────────────────────
echo ""
echo "--- orch_kb_init ---"

# Test 1: init creates knowledge directory
orch_kb_init
_assert_dir_exists "init creates knowledge directory" "$ORCHYSTRAW_HOME/knowledge"

# Test 2: init creates index file
_assert_file_exists "init creates index.txt" "$ORCHYSTRAW_HOME/knowledge/index.txt"

# Test 3: init is idempotent
orch_kb_init
_assert "init idempotent — no error" "0" "$?"

# ────────────────────────────────────────────
# Group 2: Store
# ────────────────────────────────────────────
echo ""
echo "--- orch_kb_store ---"

# Test 4: store creates entry file
orch_kb_store "patterns" "error-handling" "Always use set -euo pipefail in bash scripts."
_assert_file_exists "store creates entry file" "$ORCHYSTRAW_HOME/knowledge/patterns/error-handling.md"

# Test 5: entry file has frontmatter with domain
content=$(cat "$ORCHYSTRAW_HOME/knowledge/patterns/error-handling.md")
_assert_match "entry has domain in frontmatter" "domain: patterns" "$content"

# Test 6: entry file has key in frontmatter
_assert_match "entry has key in frontmatter" "key: error-handling" "$content"

# Test 7: entry file has created timestamp
_assert_match "entry has created timestamp" "created: [0-9]{4}-[0-9]{2}-[0-9]{2}T" "$content"

# Test 8: entry file has updated timestamp
_assert_match "entry has updated timestamp" "updated: [0-9]{4}-[0-9]{2}-[0-9]{2}T" "$content"

# Test 9: entry file has project field
_assert_match "entry has project field" "project: " "$content"

# Test 10: entry file has the actual value content
_assert_match "entry has value content" "Always use set -euo pipefail" "$content"

# Test 11: index is updated after store
index_content=$(cat "$ORCHYSTRAW_HOME/knowledge/index.txt")
_assert_match "index has entry" "patterns/error-handling" "$index_content"

# Test 12: store with empty domain fails
if orch_kb_store "" "key" "value" 2>/dev/null; then
    _assert "store with empty domain fails" "1" "0"
else
    _assert "store with empty domain fails" "1" "1"
fi

# Test 13: store with empty key fails
if orch_kb_store "patterns" "" "value" 2>/dev/null; then
    _assert "store with empty key fails" "1" "0"
else
    _assert "store with empty key fails" "1" "1"
fi

# Test 14: store second entry in same domain
orch_kb_store "patterns" "naming" "Use snake_case for bash functions."
_assert_file_exists "second entry created" "$ORCHYSTRAW_HOME/knowledge/patterns/naming.md"

# Test 15: store entry in different domain
orch_kb_store "decisions" "ui-framework" "React 19 + shadcn/ui v4 for all frontends."
_assert_file_exists "entry in decisions domain" "$ORCHYSTRAW_HOME/knowledge/decisions/ui-framework.md"

# Test 16: store preserves created timestamp on update
original_created=$(sed -n 's/^created: //p' "$ORCHYSTRAW_HOME/knowledge/patterns/error-handling.md" | head -1)
sleep 1
orch_kb_store "patterns" "error-handling" "Updated: Always use set -euo pipefail."
updated_created=$(sed -n 's/^created: //p' "$ORCHYSTRAW_HOME/knowledge/patterns/error-handling.md" | head -1)
_assert "update preserves created timestamp" "$original_created" "$updated_created"

# ────────────────────────────────────────────
# Group 3: Retrieve
# ────────────────────────────────────────────
echo ""
echo "--- orch_kb_retrieve ---"

# Test 17: retrieve returns stored content
result=$(orch_kb_retrieve "patterns" "error-handling")
_assert_match "retrieve returns content" "Always use set -euo pipefail" "$result"

# Test 18: retrieve non-existent entry returns 1
if orch_kb_retrieve "patterns" "nonexistent" 2>/dev/null; then
    _assert "retrieve missing entry fails" "1" "0"
else
    _assert "retrieve missing entry fails" "1" "1"
fi

# Test 19: retrieve strips frontmatter
result=$(orch_kb_retrieve "decisions" "ui-framework")
if echo "$result" | grep -q "^---$"; then
    _assert "retrieve strips frontmatter" "no-frontmatter" "has-frontmatter"
else
    _assert "retrieve strips frontmatter" "no-frontmatter" "no-frontmatter"
fi

# ────────────────────────────────────────────
# Group 4: Search
# ────────────────────────────────────────────
echo ""
echo "--- orch_kb_search ---"

# Test 20: search finds entry by keyword
result=$(orch_kb_search "pipefail")
_assert_match "search finds by keyword" "error-handling" "$result"

# Test 21: search finds across domains
result=$(orch_kb_search "React")
_assert_match "search finds in decisions domain" "ui-framework" "$result"

# Test 22: search returns 1 for no matches
if orch_kb_search "zzz_nonexistent_zzz" 2>/dev/null; then
    _assert "search no matches returns 1" "1" "0"
else
    _assert "search no matches returns 1" "1" "1"
fi

# Test 23: search is case-insensitive
result=$(orch_kb_search "PIPEFAIL")
_assert_match "search is case-insensitive" "error-handling" "$result"

# ────────────────────────────────────────────
# Group 5: List
# ────────────────────────────────────────────
echo ""
echo "--- orch_kb_list ---"

# Test 24: list without domain shows all domains
result=$(orch_kb_list)
_assert_match "list shows patterns domain" "patterns" "$result"

# Test 25: list shows entry counts
_assert_match "list shows entry count" "[0-9]+ entries" "$result"

# Test 26: list with domain shows entries
result=$(orch_kb_list "patterns")
_assert_match "list domain shows entries" "error-handling" "$result"

# Test 27: list non-existent domain fails
if orch_kb_list "nonexistent" 2>/dev/null; then
    _assert "list nonexistent domain fails" "1" "0"
else
    _assert "list nonexistent domain fails" "1" "1"
fi

# ────────────────────────────────────────────
# Group 6: Delete
# ────────────────────────────────────────────
echo ""
echo "--- orch_kb_delete ---"

# Test 28: delete removes entry file
orch_kb_store "tools" "shellcheck" "Use shellcheck for bash linting."
_assert_file_exists "entry exists before delete" "$ORCHYSTRAW_HOME/knowledge/tools/shellcheck.md"

orch_kb_delete "tools" "shellcheck"
_assert_file_not_exists "delete removes entry file" "$ORCHYSTRAW_HOME/knowledge/tools/shellcheck.md"

# Test 29: delete updates index
index_content=$(cat "$ORCHYSTRAW_HOME/knowledge/index.txt")
if echo "$index_content" | grep -q "tools/shellcheck"; then
    _assert "delete updates index" "removed" "still-present"
else
    _assert "delete updates index" "removed" "removed"
fi

# Test 30: delete non-existent entry returns 1
if orch_kb_delete "tools" "nonexistent" 2>/dev/null; then
    _assert "delete missing entry returns 1" "1" "0"
else
    _assert "delete missing entry returns 1" "1" "1"
fi

# Test 31: delete removes empty domain directory
if [[ ! -d "$ORCHYSTRAW_HOME/knowledge/tools" ]]; then
    _assert "delete removes empty domain dir" "removed" "removed"
else
    _assert "delete removes empty domain dir" "removed" "still-exists"
fi

# ────────────────────────────────────────────
# Group 7: Export
# ────────────────────────────────────────────
echo ""
echo "--- orch_kb_export ---"

# Test 32: export creates output file
orch_kb_export "$TEST_TMP/export.md" >/dev/null
_assert_file_exists "export creates file" "$TEST_TMP/export.md"

# Test 33: export contains header
export_content=$(cat "$TEST_TMP/export.md")
_assert_match "export has header" "Knowledge Base Export" "$export_content"

# Test 34: export contains domain section
_assert_match "export has domain section" "## patterns" "$export_content"

# Test 35: export contains entry content
_assert_match "export has entry content" "pipefail" "$export_content"

# Test 36: export contains timestamp
_assert_match "export has export timestamp" "Exported: [0-9]{4}-" "$export_content"

# Test 37: export with empty path fails
if orch_kb_export "" 2>/dev/null; then
    _assert "export with empty path fails" "1" "0"
else
    _assert "export with empty path fails" "1" "1"
fi

# ────────────────────────────────────────────
# Group 8: Merge on init
# ────────────────────────────────────────────
echo ""
echo "--- orch_kb_merge_on_init ---"

# Setup: create a fake project with local knowledge
FAKE_PROJECT="$TEST_TMP/fake-project"
mkdir -p "$FAKE_PROJECT/.orchystraw/knowledge/conventions"

# Create a project-local entry that is NEWER than global (will win)
cat > "$FAKE_PROJECT/.orchystraw/knowledge/conventions/indent.md" <<'ENTRY'
---
domain: conventions
key: indent
created: 2026-03-20T10:00:00
updated: 2026-03-20T18:00:00
project: fake-project
---
Use 2-space indentation for all YAML files.
ENTRY

# Create a global entry that is NEWER (will NOT be overwritten by local)
mkdir -p "$ORCHYSTRAW_HOME/knowledge/conventions"
cat > "$ORCHYSTRAW_HOME/knowledge/conventions/naming.md" <<'ENTRY'
---
domain: conventions
key: naming
created: 2026-03-20T08:00:00
updated: 2026-03-20T20:00:00
project: global
---
Global naming convention that is newer.
ENTRY

# Also add a project-local entry for naming that is OLDER (should not overwrite global)
cat > "$FAKE_PROJECT/.orchystraw/knowledge/conventions/naming.md" <<'ENTRY'
---
domain: conventions
key: naming
created: 2026-03-20T08:00:00
updated: 2026-03-20T12:00:00
project: fake-project
---
Old local naming convention.
ENTRY

# Test 38: merge succeeds
orch_kb_merge_on_init "$FAKE_PROJECT"
_assert "merge completes without error" "0" "$?"

# Test 39: local-only entry merged into global
_assert_file_exists "local entry merged to global" "$ORCHYSTRAW_HOME/knowledge/conventions/indent.md"

# Test 40: newer global entry NOT overwritten by older local
global_naming=$(cat "$ORCHYSTRAW_HOME/knowledge/conventions/naming.md")
_assert_match "newer global preserved (not overwritten)" "Global naming convention that is newer" "$global_naming"

# Test 41: global entries copied into project-local cache
_assert_file_exists "global entry copied to project cache" "$FAKE_PROJECT/.orchystraw/knowledge/patterns/error-handling.md"

# Test 42: merge with empty project root fails
if orch_kb_merge_on_init "" 2>/dev/null; then
    _assert "merge with empty root fails" "1" "0"
else
    _assert "merge with empty root fails" "1" "1"
fi

# ────────────────────────────────────────────
# Group 9: Double-source guard
# ────────────────────────────────────────────
echo ""
echo "--- double-source guard ---"

# Test 43: sourcing again doesn't error
source "$PROJECT_ROOT/src/core/knowledge-base.sh"
_assert "double-source guard works" "1" "$_ORCH_KNOWLEDGE_BASE_LOADED"

# ────────────────────────────────────────────
# Group 10: Bootstrap knowledge on init (#57)
# ────────────────────────────────────────────
echo ""
echo "--- bootstrap knowledge on init ---"

# Source init-project.sh (which provides orch_init_bootstrap_knowledge)
source "$PROJECT_ROOT/src/core/init-project.sh"

# Test 44: bootstrap creates global knowledge directory
BOOTSTRAP_TMP="$(mktemp -d)"
export ORCHYSTRAW_HOME="$BOOTSTRAP_TMP/orch-home"
export _ORCH_KB_DIR="$ORCHYSTRAW_HOME/knowledge"
BOOTSTRAP_PROJECT="$BOOTSTRAP_TMP/myproject"
mkdir -p "$BOOTSTRAP_PROJECT"

domain_count=$(orch_init_bootstrap_knowledge "$BOOTSTRAP_PROJECT" 2>/dev/null)
_assert "bootstrap returns 5 default domains" "5" "$domain_count"

# Test 45: global domain directories exist
_assert_dir_exists "global patterns dir" "$ORCHYSTRAW_HOME/knowledge/patterns"
_assert_dir_exists "global decisions dir" "$ORCHYSTRAW_HOME/knowledge/decisions"
_assert_dir_exists "global anti-patterns dir" "$ORCHYSTRAW_HOME/knowledge/anti-patterns"
_assert_dir_exists "global tools dir" "$ORCHYSTRAW_HOME/knowledge/tools"
_assert_dir_exists "global conventions dir" "$ORCHYSTRAW_HOME/knowledge/conventions"

# Test 46: project-local knowledge cache exists
_assert_dir_exists "local patterns dir" "$BOOTSTRAP_PROJECT/.orchystraw/knowledge/patterns"
_assert_dir_exists "local decisions dir" "$BOOTSTRAP_PROJECT/.orchystraw/knowledge/decisions"
_assert_dir_exists "local anti-patterns dir" "$BOOTSTRAP_PROJECT/.orchystraw/knowledge/anti-patterns"
_assert_dir_exists "local tools dir" "$BOOTSTRAP_PROJECT/.orchystraw/knowledge/tools"
_assert_dir_exists "local conventions dir" "$BOOTSTRAP_PROJECT/.orchystraw/knowledge/conventions"

# Test 47: global index.txt exists
_assert_file_exists "global index.txt created" "$ORCHYSTRAW_HOME/knowledge/index.txt"

# Test 48: idempotent — running again doesn't error
domain_count2=$(orch_init_bootstrap_knowledge "$BOOTSTRAP_PROJECT" 2>/dev/null)
_assert "bootstrap idempotent (returns 5 again)" "5" "$domain_count2"

rm -rf "$BOOTSTRAP_TMP"

# ────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
