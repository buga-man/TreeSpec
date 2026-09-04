#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Run all per-skill tests + new validation-group tests in this repo.
#
# Two parallel loops with different conventions:
#
#   SKILLS — each skill has: test-structure.sh, test-contract.sh, scenarios.md.
#           We auto-run the .sh scripts; scenarios.md are documentation.
#           The skill loop requires scenarios.md to exist.
#
#   VALIDATION_GROUPS — manifest / spec / router rule tests; only test-rules.sh.
#                       No scenarios.md required (these aren't skill procedures).
#                       Single test script per group.
#
# The synthetic harness (tests/fixtures/test-synthetic.sh) is NOT wired into
# this runner — it runs separately (REQ-VALID-001 AC-5 + T-06 AC-6).
#
# Final aggregate: exits 0 iff every script (SKILLS + VALIDATION_GROUPS) exits 0.
# ════════════════════════════════════════════════════════════════

set -u

cd "$(dirname "$0")/.." || exit 2

SKILLS=(intake session-resume brainstorm write-spec plan implement verify log)
VALIDATION_GROUPS=(manifest spec router)

PASS=0
FAIL=0
FAILED=()

printf "Running per-skill tests in %s\n\n" "$(pwd)"

# ── SKILLS loop ──────────────────────────────────────
# Behaviour preserved bit-identical with the pre-T-07 runner. Auto-discovers
# every test-*.sh under tests/$skill/, so skill-specific extras (e.g. log's
# test-self-contained.sh) get picked up without hard-coding. Requires
# scenarios.md for each skill. Per-failure diagnostic unchanged.

for skill in "${SKILLS[@]}"; do
    printf "━━━ %s ━━━\n" "$skill"

    # Auto-discover test scripts in canonical order (structure first,
    # then contract, then anything else).
    scripts=$(ls "tests/$skill"/test-*.sh 2>/dev/null | sort)
    if [ -z "$scripts" ]; then
        printf "  ✗ tests/%s/ — no test-*.sh scripts\n" "$skill"
        FAIL=$((FAIL + 1))
        continue
    fi

    for script in $scripts; do
        if [ ! -f "$script" ]; then
            printf "  ✗ %s — file not found\n" "$script"
            FAIL=$((FAIL + 1))
            FAILED+=("$script")
            continue
        fi

        # Each test exits with number of failed assertions. We don't
        # propagate; we run all scripts and tally.
        if bash "$script" >/tmp/test-$skill-$(basename "$script" .sh).log 2>&1; then
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
        printf "  ✗ %s — scenarios.md not found\n" "$tests/$skill/"
        FAIL=$((FAIL + 1))
    fi
done

# ── VALIDATION_GROUPS loop ─────────────────────────────────────
# Additive loop. Looks only for test-rules.sh; does NOT require
# scenarios.md (validation groups aren't skill procedures — they're
# rule checks derived from CON-10 + the router validation procedure).
# Per-failure diagnostic format mirrors the SKILLS loop.

for group in "${VALIDATION_GROUPS[@]}"; do
    printf "━━━ %s ━━━\n" "$group"

    script="tests/$group/test-rules.sh"
    if [ ! -f "$script" ]; then
        printf "  ✗ %s — file not found\n" "$script"
        FAIL=$((FAIL + 1))
        FAILED+=("$script")
        continue
    fi

    if bash "$script" >/tmp/test-$group-$(basename "$script" .sh).log 2>&1; then
        printf "  ✓ %s\n" "$script"
        PASS=$((PASS + 1))
    else
        printf "  ✗ %s\n" "$script"
        cat /tmp/test-$group-$(basename "$script" .sh).log
        FAIL=$((FAIL + 1))
        FAILED+=("$script")
    fi
done

# ── BACKWARD_COMPAT group (REQ-VALID-002 / EPIC-006, DoD-3 phase 1) ─
# A frozen phase_0 manifest fixture is guarded by
# tests/manifest/test-backward-compat.sh. Any new manifest rule that
# breaks the fixture (would silently cut off pre-v0.2 consumers) must be
# deferred, opted in via [kernel].compatibility='lenient', or
# accompanied by migration notes. Its exit code aggregates with the rest.

printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "backward-compat\n"
bwc_script="tests/manifest/test-backward-compat.sh"
if [ ! -f "$bwc_script" ]; then
    printf "  ✗ %s — file not found\n" "$bwc_script"
    FAIL=$((FAIL + 1))
    FAILED+=("$bwc_script")
elif bash "$bwc_script" >/tmp/test-bwc-$(basename "$bwc_script" .sh).log 2>&1; then
    printf "  ✓ %s\n" "$bwc_script"
    PASS=$((PASS + 1))
else
    printf "  ✗ %s\n" "$bwc_script"
    cat /tmp/test-bwc-$(basename "$bwc_script" .sh).log
    FAIL=$((FAIL + 1))
    FAILED+=("$bwc_script")
fi

# ── EPIC-010 execution-log tests (REQ-EXEC-002 / .runs/) ─────────
# The append-only execution-log writer is exercised end-to-end by
# tests/runs/test-runs.sh (AC-1..AC-4). Additive: its exit code
# aggregates with the rest, like the backward-compat group above.

printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "runs (EPIC-010)\n"
runs_script="tests/runs/test-runs.sh"
if [ ! -f "$runs_script" ]; then
    printf "  ✗ %s — file not found\n" "$runs_script"
    FAIL=$((FAIL + 1))
    FAILED+=("$runs_script")
elif bash "$runs_script" >/tmp/test-runs-$(basename "$runs_script" .sh).log 2>&1; then
    printf "  ✓ %s\n" "$runs_script"
    PASS=$((PASS + 1))
else
    printf "  ✗ %s\n" "$runs_script"
    cat /tmp/test-runs-$(basename "$runs_script" .sh).log
    FAIL=$((FAIL + 1))
    FAILED+=("$runs_script")
fi

# ── EPIC-011 execution-mode tests (REQ-EXEC-003 / single, best-of-n, consensus) ─
# The record-layer execution modes are exercised end-to-end by
# tests/runs/test-exec-modes.sh (AC-1..AC-4). Additive: its exit code
# aggregates with the rest, like the runs and backward-compat groups above.

printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "exec-modes (EPIC-011)\n"
em_script="tests/runs/test-exec-modes.sh"
if [ ! -f "$em_script" ]; then
    printf "  ✗ %s — not found\n" "$em_script"
    FAIL=$((FAIL + 1))
    FAILED+=("$em_script")
elif bash "$em_script" >/tmp/test-em-$(basename "$em_script" .sh).log 2>&1; then
    printf "  ✓ %s\n" "$em_script"
    PASS=$((PASS + 1))
else
    printf "  ✗ %s\n" "$em_script"
    cat /tmp/test-em-$(basename "$em_script" .sh).log
    FAIL=$((FAIL + 1))
    FAILED+=("$em_script")
fi

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
