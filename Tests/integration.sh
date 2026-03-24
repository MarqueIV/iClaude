#!/bin/bash
# Manual integration test script for iclaude.
# Run from the package root:  ./Tests/integration.sh
#
# Prerequisites:
#   1. swift build (done by this script)
#   2. Reminders access granted — run `.build/debug/iclaude lists` manually
#      once to trigger the macOS privacy dialog, then re-run this script.

set -euo pipefail

BINARY=".build/debug/iclaude"
PREFIX="__iclaude_test_$$__"   # $$ = PID, unique per run
PASS=0
FAIL=0

# ── helpers ───────────────────────────────────────────────────────────────────

green() { printf "\033[32m✓ %s\033[0m\n" "$1"; }
red()   { printf "\033[31m✗ %s\033[0m\n" "$1"; }

pass() { green "$1"; ((PASS++)) || true; }
fail() { red   "$1"; ((FAIL++)) || true; }

assert_exit_ok()  { [[ "$1" -eq 0 ]]  && pass "$2" || fail "$2 (exit $1)"; }
assert_exit_err() { [[ "$1" -ne 0 ]]  && pass "$2" || fail "$2 (expected non-zero)"; }

assert_contains() {
    echo "$1" | python3 -c "
import sys, json
data = json.load(sys.stdin)
key  = sys.argv[1]
val  = sys.argv[2]

def find(obj):
    if isinstance(obj, dict):
        return str(obj.get(key)) == val
    if isinstance(obj, list):
        return any(find(i) for i in obj)
    return False

sys.exit(0 if find(data) else 1)
" "$2" "$3" \
        && pass "$4" || fail "$4 (looking for $2=$3 in: $1)"
}

assert_has_key() {
    echo "$1" | python3 -c "
import sys, json
data = json.load(sys.stdin)
key  = sys.argv[1]
def has(obj):
    if isinstance(obj, dict): return key in obj
    if isinstance(obj, list): return any(has(i) for i in obj)
    return False
sys.exit(0 if has(data) else 1)
" "$2" \
        && pass "$3" || fail "$3 (key '$2' not found in: $1)"
}

assert_json_array() {
    echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if isinstance(d,list) else 1)" \
        && pass "$2" || fail "$2 (not a JSON array: $1)"
}

assert_json_object() {
    echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if isinstance(d,dict) else 1)" \
        && pass "$2" || fail "$2 (not a JSON object: $1)"
}

# ── build ─────────────────────────────────────────────────────────────────────

echo "Building..."
swift build 2>&1 | tail -3
echo ""

# ── discover lists ────────────────────────────────────────────────────────────

echo "=== Discovering lists ==="
LISTS_OUT=$("$BINARY" lists)
assert_exit_ok $? "lists: exits 0"
assert_json_array "$LISTS_OUT" "lists: returns JSON array"

LIST_NAME=$(echo "$LISTS_OUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not data:
    print('__NONE__')
else:
    print(data[0]['name'])
")

if [[ "$LIST_NAME" == "__NONE__" ]]; then
    echo ""
    echo "No reminder lists found. Create one in Reminders.app and re-run."
    exit 1
fi

echo "Using list: '$LIST_NAME'"
echo ""

# ── lists flags ───────────────────────────────────────────────────────────────

echo "=== lists --pretty ==="
PRETTY_OUT=$("$BINARY" lists --pretty)
[[ "$PRETTY_OUT" == *"  "* ]] && pass "lists --pretty: output is indented" \
                               || fail "lists --pretty: expected indentation"
echo ""

# ── list (single) ─────────────────────────────────────────────────────────────

echo "=== list <name> ==="
LIST_OUT=$("$BINARY" list "$LIST_NAME"); EXIT=$?
assert_exit_ok   $EXIT            "list: exits 0"
assert_json_array "$LIST_OUT"     "list: returns JSON array"

BAD_OUT=$("$BINARY" list "__nope__" 2>/dev/null || true)
assert_json_object "$BAD_OUT"     "list unknown: returns JSON object"
assert_has_key     "$BAD_OUT" "error" "list unknown: has 'error' key"
echo ""

# ── add ───────────────────────────────────────────────────────────────────────

echo "=== add ==="
TITLE_BASIC="${PREFIX}_basic"
ADD_OUT=$("$BINARY" add "$TITLE_BASIC" --list "$LIST_NAME"); EXIT=$?
assert_exit_ok $EXIT                         "add: exits 0"
assert_json_object "$ADD_OUT"                "add: returns JSON object"
assert_contains "$ADD_OUT" "title"    "$TITLE_BASIC"   "add: title matches"
assert_contains "$ADD_OUT" "isCompleted" "False"        "add: isCompleted=false" || \
assert_contains "$ADD_OUT" "isCompleted" "false"        "add: isCompleted=false"

TITLE_DUE="${PREFIX}_due"
DUE_OUT=$("$BINARY" add "$TITLE_DUE" --list "$LIST_NAME" --due "2099-06-15"); EXIT=$?
assert_exit_ok $EXIT                         "add --due: exits 0"
assert_has_key "$DUE_OUT" "dueDate"          "add --due: response has dueDate"
echo "$DUE_OUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert '2099' in (d.get('dueDate') or ''), f'expected 2099 in dueDate, got: {d}'
" && pass "add --due: dueDate contains 2099" || fail "add --due: dueDate does not contain 2099"

TITLE_NOTES="${PREFIX}_notes"
NOTES_OUT=$("$BINARY" add "$TITLE_NOTES" --list "$LIST_NAME" --notes "test notes"); EXIT=$?
assert_exit_ok $EXIT                         "add --notes: exits 0"
assert_contains "$NOTES_OUT" "notes" "test notes" "add --notes: notes matches"

TITLE_PRI="${PREFIX}_pri"
PRI_OUT=$("$BINARY" add "$TITLE_PRI" --list "$LIST_NAME" --priority "1"); EXIT=$?
assert_exit_ok $EXIT                         "add --priority: exits 0"
assert_contains "$PRI_OUT" "priority" "1"    "add --priority: priority=1"

BAD_DATE_OUT=$("$BINARY" add "ignore" --list "$LIST_NAME" --due "not-a-date" 2>/dev/null || true)
assert_has_key "$BAD_DATE_OUT" "error"       "add bad date: has 'error' key"
echo ""

# ── list shows added reminders ────────────────────────────────────────────────

echo "=== list shows added reminders ==="
CURRENT=$("$BINARY" list "$LIST_NAME")
echo "$CURRENT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
title = sys.argv[1]
assert any(r.get('title') == title for r in data), f'{title} not found in list'
" "$TITLE_BASIC" && pass "list: added reminder appears" \
                 || fail  "list: added reminder missing"
echo ""

# ── complete ──────────────────────────────────────────────────────────────────

echo "=== complete ==="
COMP_OUT=$("$BINARY" complete "$TITLE_BASIC" --list "$LIST_NAME"); EXIT=$?
assert_exit_ok $EXIT                          "complete: exits 0"
assert_json_object "$COMP_OUT"                "complete: returns JSON object"
assert_contains "$COMP_OUT" "success" "True"  "complete: success=true" || \
assert_contains "$COMP_OUT" "success" "true"  "complete: success=true"

# Verify isCompleted in list
AFTER=$("$BINARY" list "$LIST_NAME")
echo "$AFTER" | python3 -c "
import sys, json
data  = json.load(sys.stdin)
title = sys.argv[1]
match = next((r for r in data if r.get('title') == title), None)
assert match is not None, f'{title} not found'
assert match.get('isCompleted') == True, f'isCompleted not True: {match}'
" "$TITLE_BASIC" && pass "complete: isCompleted=true in list" \
                 || fail  "complete: isCompleted not updated"

BAD_COMP=$("$BINARY" complete "__nope__" --list "$LIST_NAME" 2>/dev/null || true)
assert_has_key "$BAD_COMP" "error"            "complete unknown: has 'error' key"
echo ""

# ── edit ──────────────────────────────────────────────────────────────────────

echo "=== edit ==="
TITLE_EDIT="${PREFIX}_edit"
TITLE_RENAMED="${PREFIX}_edited"
"$BINARY" add "$TITLE_EDIT" --list "$LIST_NAME" > /dev/null

EDIT_OUT=$("$BINARY" edit "$TITLE_EDIT" --list "$LIST_NAME" --title "$TITLE_RENAMED"); EXIT=$?
assert_exit_ok $EXIT                              "edit --title: exits 0"
assert_contains "$EDIT_OUT" "title" "$TITLE_RENAMED" "edit --title: new title in response"

EDIT_DUE_OUT=$("$BINARY" edit "$TITLE_RENAMED" --list "$LIST_NAME" --due "2099-12-31"); EXIT=$?
assert_exit_ok $EXIT                              "edit --due: exits 0"
echo "$EDIT_DUE_OUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert '2099' in (d.get('dueDate') or ''), f'expected 2099 in dueDate'
" && pass "edit --due: dueDate updated" || fail "edit --due: dueDate not updated"

EDIT_NOTES_OUT=$("$BINARY" edit "$TITLE_RENAMED" --list "$LIST_NAME" --notes "edited notes"); EXIT=$?
assert_exit_ok $EXIT                              "edit --notes: exits 0"
assert_contains "$EDIT_NOTES_OUT" "notes" "edited notes" "edit --notes: notes updated"

EDIT_PRI_OUT=$("$BINARY" edit "$TITLE_RENAMED" --list "$LIST_NAME" --priority "5"); EXIT=$?
assert_exit_ok $EXIT                              "edit --priority: exits 0"
assert_contains "$EDIT_PRI_OUT" "priority" "5"   "edit --priority: priority updated"
echo ""

# ── delete ────────────────────────────────────────────────────────────────────

echo "=== delete ==="
DEL_OUT=$("$BINARY" delete "$TITLE_BASIC" --list "$LIST_NAME"); EXIT=$?
assert_exit_ok $EXIT                         "delete: exits 0"
assert_json_object "$DEL_OUT"                "delete: returns JSON object"
assert_contains "$DEL_OUT" "success" "True"  "delete: success=true" || \
assert_contains "$DEL_OUT" "success" "true"  "delete: success=true"

# Verify gone
AFTER_DEL=$("$BINARY" list "$LIST_NAME")
echo "$AFTER_DEL" | python3 -c "
import sys, json
data  = json.load(sys.stdin)
title = sys.argv[1]
found = any(r.get('title') == title for r in data)
assert not found, f'{title} still present after delete'
" "$TITLE_BASIC" && pass "delete: reminder gone from list" \
                 || fail  "delete: reminder still present"

BAD_DEL=$("$BINARY" delete "__nope__" --list "$LIST_NAME" 2>/dev/null || true)
assert_has_key "$BAD_DEL" "error"            "delete unknown: has 'error' key"
echo ""

# ── cleanup ───────────────────────────────────────────────────────────────────

echo "=== cleanup ==="
for TITLE in "$TITLE_DUE" "$TITLE_NOTES" "$TITLE_PRI" "$TITLE_RENAMED"; do
    "$BINARY" delete "$TITLE" --list "$LIST_NAME" > /dev/null 2>&1 || true
done
pass "cleanup: test reminders removed"
echo ""

# ── summary ───────────────────────────────────────────────────────────────────

echo "────────────────────────────"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed"
[[ $FAIL -eq 0 ]] && echo -e "\033[32mAll tests passed.\033[0m" \
                  || echo -e "\033[31m$FAIL test(s) failed.\033[0m"
echo ""
[[ $FAIL -eq 0 ]]
