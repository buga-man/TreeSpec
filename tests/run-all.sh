#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Run all per-skill tests in this repo.
# Each skill has: test-structure.sh, test-contract.sh, scenarios.md.
# We only auto-run the .sh scripts; scenarios.md are documentation.
# ════════════════════════════════════════════════════════════════

set -u

cd "$(dirname "$0")/.." || exit 2

SKILLS=(intake session-resume brainstorm write-spec plan implement verify)

PASS=0
FAIL=0
FAILED=()

printf "Running per-skill tests in %s\n\n" "$(pwd)"

for skill in "${SKILLS[@]}"; do
    printf "━━━ %s ━━━\n" "$skill"

    for script in "tests/$skill/test-structure.sh" "tests/$skill/test-contract.sh"; do
        if [ ! -f "$script" ]; then
            printf "  ✗ %s — file not found\n" "$script"
            FAIL=$((FAIL + 1))
            FAILED+=("$script")
            continue
        fi

        # Each test exits with number of failed assertions. We don't
        # propagate; we run all scripts and tally.
        if bash "$script" > /tmp/test-$skill-$(basename "$script" .sh).log 2>&1; then
            printf "  ✓ %s\n" "$script"
            PASS=$((PASS + 1))
        else
            printf "  ✗ %s\n" "$script"
            cat /tmp/test-$skill-$(basename "$script" .sh).log
            FAIL=$((FAIL + 1))
            FAILED+=("$script")
        fi
    done

    # Scenarios are documentation; check they exist.
    if [ -f "tests/$skill/scenarios.md" ]; then
        printf "  · %s (documentation)\n" "tests/$skill/scenarios.md"
    else
        printf "  ✗ %s — scenarios.md not found\n" "tests/$skill/"
        FAIL=$((FAIL + 1))
    fi
done

printf "\n════════════════════════════════════════════════════════════════\n"
printf "Result: %d passed, %d failed\n" "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
    printf "Failed tests:\n"
    for f in "${FAILED[@]}"; do
        printf "  - %s\n" "$f"
    done
    exit 1
fi

exit 0