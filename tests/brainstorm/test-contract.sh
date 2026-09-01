#!/usr/bin/env bash
# Tests for the brainstorm skill — contract assertions matching
# specs/REQ-BRAIN-001.md.

. "$(dirname "$0")/../_lib/common.sh"

section "brainstorm — contract (matches REQ-BRAIN-001)"

SKILL=skills/tree-spec/core-capabilities/brainstorm/SKILL.md

# AC-1: file exists.
assert_file_exists "$SKILL" "AC-1: skill file exists"

# AC-2: classification=stochastic.
assert_grep "$SKILL" 'classification: stochastic' "AC-2: classification=stochastic"

# AC-3: context-reading step references artifacts.
assert_grep "$SKILL" 'artifacts/INDEX.md' "AC-3: references artifacts/INDEX.md"
assert_grep "$SKILL" 'global/biz-spec' "AC-3: references global/biz-spec/"

# AC-4: output includes L0 fields.
assert_grep "$SKILL" '^### Step 3\.' "AC-4: Step 3 (generate draft) exists"
assert_grep "$SKILL" 'acceptance_criteria' "AC-4: AC field mentioned"
assert_grep "$SKILL" 'provenance' "AC-4: provenance field mentioned"

# AC-5: no write operations in side_effects.
assert_grep "$SKILL" '^side_effects:' "AC-5: side_effects section exists"
assert_grep "$SKILL" '\b(writes|creates a file)\b' "AC-5: no write-side-effect keywords" 1 1

# AC-6: body does NOT write directly to global/biz-spec.
assert_grep "$SKILL" 'global/biz-spec/REQ-' "AC-6: body does not write specs directly" 1 1

# AC-7: source_doc handling (Step 1.5).
assert_grep "$SKILL" 'source_doc' "AC-7: source_doc referenced in body"
assert_grep "$SKILL" 'Step 1\.5' "AC-7: Step 1.5 exists for source_doc"
assert_grep "$SKILL" 'source_candidates' "AC-7: source_candidates output field referenced"

# AC-8: anti-pattern for silent multi-draft emission.
assert_grep "$SKILL" 'multiple L0 drafts|one run = one draft' "AC-8: anti-pattern explicitly forbids multi-draft"

report_and_exit