#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tests/manifest/test-backward-compat.sh — phase_0 manifest gate
#
# REQ-VALID-002 / EPIC-006 (DoD-3 phase 1): any new manifest rule that
# silently breaks the frozen phase_0 manifest would cut off consumers
# that have not yet upgraded. This script turns "did we break anyone?"
# into a mechanical CI check.
#
# It runs every manifest assertion (tests/manifest/test-rules.sh) against
# the frozen baseline tests/fixtures/phase_0_manifest.toml. The four
# v0.2-era asserts (003, 010, 013, 014) are reported as explicit SKIPs
# with reason on the pre-v0.2 fixture — the deferral mandated by
# phase_1.md § Эпик-1.2. Skips never affect the exit code.
#
# Exit 0 iff every assert passes (the pre-v0.2 deferral skips are
# expected and do not count as failures).
#
# Drift guard: when the framework-repo canonical source is present, the
# fixture must stay a verbatim copy — FAIL on divergence (a deliberate
# re-freeze is required). On standalone checkouts where the source is
# absent, the guard is an explicit SKIP.
# ════════════════════════════════════════════════════════════════

. "$(dirname "$0")/../_lib/common.sh"

section "manifest — backward-compat (phase_0 fixture, REQ-VALID-002)"

FIXTURE="$TESTS_PROJECT_ROOT/tests/fixtures/phase_0_manifest.toml"
SRC="$TESTS_PROJECT_ROOT/documents/phases/phase_0/tree-spec.toml"

# ── Drift guard (T-02 AC-5) ────────────────────────────────────
if [ -f "$SRC" ]; then
    if diff -q "$SRC" "$FIXTURE" > /dev/null 2>&1; then
        _log_pass "ASSERT-MANIFEST-BWC-001: fixture is a verbatim copy of the canonical phase_0 source"
    else
        _log_fail "ASSERT-MANIFEST-BWC-001: fixture diverges from canonical phase_0 source" \
                  "re-freeze: cp documents/phases/phase_0/tree-spec.toml tests/fixtures/phase_0_manifest.toml"
    fi
else
    printf "  ${C_YELLOW}~${C_RESET} SKIP ASSERT-MANIFEST-BWC-001: canonical source absent (standalone checkout)\n"
fi

# ── Run the full rule suite against the frozen baseline ─────────
# TESTS_MANIFEST is project-root-relative, matching the convention
# expected by tests/manifest/test-rules.sh (and common.sh's default).
TESTS_MANIFEST="tests/fixtures/phase_0_manifest.toml"

if bash "$TESTS_PROJECT_ROOT/tests/manifest/test-rules.sh"; then
    _log_pass "ASSERT-MANIFEST-BWC-002: all manifest asserts pass against the phase_0 fixture"
else
    _log_fail "ASSERT-MANIFEST-BWC-002: a manifest assert fails against the phase_0 fixture" \
              "defer the breaking rule, opt in via [kernel].compatibility='lenient', or add migration notes"
fi

report_and_exit
