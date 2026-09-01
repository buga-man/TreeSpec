#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Test helpers — shared across all per-skill test scripts.
# Sourced via: `. "$(dirname "$0")/../_lib/common.sh"`
#
# Conventions:
#   - Each test is a sequence of `assert_*` calls.
#   - On failure, prints a one-line diagnostic and increments the
#     failure counter; the script exits non-zero at the end if any
#     assertion failed.
#   - Exit code = number of failed assertions (capped at 255).
#
# Usage:
#   #!/usr/bin/env bash
#   . "$(dirname "$0")/../_lib/common.sh"
#   assert_file_exists "skills/brainstorm/SKILL.md" "brainstorm exists"
#   report_and_exit
# ════════════════════════════════════════════════════════════════

set -u

# Resolve paths relative to the project root (where `tests/` lives).
TESTS_PROJECT_ROOT="${TESTS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TESTS_KIT_ROOT="${TESTS_KIT_ROOT:-$TESTS_PROJECT_ROOT}"

# Counters.
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_FAILED_NAMES=()

# Colors (auto-disabled when stdout is not a TTY).
if [ -t 1 ]; then
    C_GREEN="\033[32m"
    C_RED="\033[31m"
    C_YELLOW="\033[33m"
    C_RESET="\033[0m"
else
    C_GREEN=""
    C_RED=""
    C_YELLOW=""
    C_RESET=""
fi

_log_pass() {
    printf "  ${C_GREEN}\xe2\x9c\x94${C_RESET} %s\n" "$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

_log_fail() {
    printf "  ${C_RED}\xe2\x9c\x97${C_RESET} %s\n" "$1"
    [ $# -ge 2 ] && printf "      ${C_YELLOW}hint:${C_RESET} %s\n" "$2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_FAILED_NAMES+=("$1")
}

assert_file_exists() {
    local path="$1" name="$2"
    if [ -f "$TESTS_PROJECT_ROOT/$path" ]; then
        _log_pass "$name"
    else
        _log_fail "$name" "expected file at: $path"
    fi
}

assert_dir_exists() {
    local path="$1" name="$2"
    if [ -d "$TESTS_PROJECT_ROOT/$path" ]; then
        _log_pass "$name"
    else
        _log_fail "$name" "expected directory at: $path"
    fi
}

assert_grep() {
    # assert_grep <file> <pattern> <name> [min_count] [must_not]
    # If must_not=1, inverts: pattern should NOT appear.
    local file="$1" pattern="$2" name="$3" min="${4:-1}" must_not="${5:-0}"
    local full="$TESTS_PROJECT_ROOT/$file"
    if [ ! -f "$full" ]; then
        _log_fail "$name" "file not found: $file"
        return
    fi
    # `grep -c` can return multi-line output on some shells; force a single integer.
    local count
    count=$(grep -cE "$pattern" "$full" 2>/dev/null | head -n 1 | tr -d '[:space:]')
    [ -z "$count" ] && count=0
    if [ "$must_not" = "1" ]; then
        if [ "$count" = "0" ]; then
            _log_pass "$name"
        else
            _log_fail "$name" "pattern should NOT appear, but found $count times: $pattern"
        fi
    else
        if [ "$count" -ge "$min" ]; then
            _log_pass "$name"
        else
            _log_fail "$name" "expected >=$min matches of '$pattern', got $count"
        fi
    fi
}

assert_python() {
    # assert_python <expression> <name> [hint]
    # Runs `python -c "<expression>"` and passes if exit code is 0.
    # The literal string `__PROJECT_ROOT__` in the expression is replaced
    # with the project root path (Windows-normalized) before execution.
    # This avoids bash variable-scoping issues with `set -u`.
    local expr="$1" name="$2" hint="${3:-}"
    local project_root_norm
    project_root_norm="$(cd "$TESTS_PROJECT_ROOT" && pwd -W 2>/dev/null || pwd)"
    # Replace __PROJECT_ROOT__ with the actual path. Use python to do the
    # replacement so any backslashes in the path are handled safely.
    local replaced_expr="$expr"
    replaced_expr="${replaced_expr//__PROJECT_ROOT__/$project_root_norm}"
    if python -c "$replaced_expr" >/dev/null 2>&1; then
        _log_pass "$name"
    else
        _log_fail "$name" "${hint:-python expression failed: $replaced_expr}"
    fi
}

assert_toml_field() {
    # assert_toml_field <toml_file> <dotted_path> <name> [expected_value]
    # Existence-only (no expected_value) uses the python exit code — never
    # stdout — to avoid Windows console encoding crashes when the resolved
    # value contains non-ASCII characters (e.g., '→' in stage descriptions).
    local file="$1" path="$2" name="$3" expected="${4:-}"
    local full="$TESTS_PROJECT_ROOT/$file"
    if [ ! -f "$full" ]; then
        _log_fail "$name" "TOML file not found: $file"
        return
    fi
    if [ -n "$expected" ]; then
        # Compare actual value to expected — capture stdout (rare path;
        # callers should prefer assert_python for non-ASCII-tolerant checks).
        local actual
        actual=$(PYTHONIOENCODING=utf-8 python -c "
import sys, tomllib
d = tomllib.load(open(sys.argv[1], 'rb'))
for k in sys.argv[2].split('.'):
    d = d[k]
sys.stdout.write(repr(d))
" "$full" "$path" 2>/dev/null) || actual="<error>"
        if [ "$actual" = "$expected" ]; then
            _log_pass "$name"
        else
            _log_fail "$name" "expected '$expected', got '$actual' at $path"
        fi
    else
        # Existence check — use python exit code only. Avoids encoding
        # crashes; covers keys whose values include any unicode.
        if PYTHONIOENCODING=utf-8 python -c "
import sys, tomllib
d = tomllib.load(open(sys.argv[1], 'rb'))
for k in sys.argv[2].split('.'):
    d = d[k]
sys.exit(0)
" "$full" "$path" 2>/dev/null; then
            _log_pass "$name"
        else
            _log_fail "$name" "could not read $path in $file"
        fi
    fi
}

section() {
    printf "\n${C_YELLOW}== %s ==${C_RESET}\n" "$1"
}

report_and_exit() {
    printf "\n"
    if [ "$TESTS_FAILED" -eq 0 ]; then
        printf "${C_GREEN}PASS${C_RESET} — %d assertions\n" "$TESTS_PASSED"
        exit 0
    else
        printf "${C_RED}FAIL${C_RESET} — %d passed, %d failed\n" "$TESTS_PASSED" "$TESTS_FAILED"
        exit 1
    fi
}