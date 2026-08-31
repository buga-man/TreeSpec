#!/usr/bin/env bash
# Tests for the verify skill — contract assertions matching
# specs/REQ-VERIFY-001.md.

. "$(dirname "$0")/../_lib/common.sh"

section "verify — contract (matches REQ-VERIFY-001)"

SKILL=skills/verify/SKILL.md

# AC-1: file exists.
assert_file_exists "$SKILL" "AC-1: skill file exists"

# AC-2: classification=pure.
assert_grep "$SKILL" 'classification: pure' "AC-2: classification=pure"

# AC-3: oracle execution per AC.
assert_grep "$SKILL" 'oracle' "AC-3: oracle mentioned" 4
assert_grep "$SKILL" 'observed' "AC-3: observed values mentioned"
assert_grep "$SKILL" 'verification\.command' "AC-3: verification.command referenced"

# AC-4: evidence files for ACs with evidence_required.
assert_grep "$SKILL" 'evidence_required' "AC-4: evidence_required referenced"
assert_grep "$SKILL" 'evidence_format' "AC-4: evidence_format referenced"
assert_grep "$SKILL" 'docs/evidence' "AC-4: docs/evidence path referenced"

# AC-5: FAIL triggers conflict doc + return to stage 3.
assert_grep "$SKILL" 'FAIL' "AC-5: FAIL handling mentioned"
assert_grep "$SKILL" 'conflict-NNN' "AC-5: conflict-NNN mentioned"
assert_grep "$SKILL" 'return to stage 3' "AC-5: return to stage 3 mentioned"

# AC-6: anti-pattern explicitly forbids code edits.
assert_grep "$SKILL" '(Editing code from verify|fix the code|do not.*fix)' "AC-6: anti-pattern forbids code edits" 1

# AC-7: pass/fail/skip/manual_pending statuses present.
assert_grep "$SKILL" 'PASS' "AC-7: PASS status mentioned"
assert_grep "$SKILL" 'FAIL' "AC-7: FAIL status mentioned"
assert_grep "$SKILL" 'SKIP' "AC-7: SKIP status mentioned"
assert_grep "$SKILL" 'manual_pending' "AC-7: MANUAL_PENDING status mentioned"

report_and_exit