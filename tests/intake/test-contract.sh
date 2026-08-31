#!/usr/bin/env bash
# Tests for the intake skill — contract assertions matching
# artifacts/global/biz-spec/REQ-INTAKE-001.md.

. "$(dirname "$0")/../_lib/common.sh"

section "intake — contract (matches REQ-INTAKE-001)"

SKILL=skills/intake/SKILL.md

# AC-1: intake buffer exists with the candidate schema.
assert_file_exists "artifacts/intake/REQUIREMENTS.md" "AC-1: intake buffer exists"
assert_grep "artifacts/intake/REQUIREMENTS.md" 'Cand-ID' "AC-1: candidate table has Cand-ID column"

# AC-2: skill file exists and is declared in the manifest.
assert_file_exists "$SKILL" "AC-2: skill file exists"
assert_python "
import tomllib
d = tomllib.load(open('__PROJECT_ROOT__/tree-spec.toml', 'rb'))
assert 'intake' in d['pipeline']['skills'], 'intake not declared in [pipeline.skills]'
print('OK')
" "AC-2: [pipeline.skills.intake] declared in manifest"

# AC-3: normalization into candidate rows, appended (not rewritten).
assert_grep "$SKILL" 'REQUIREMENTS\.md|Cand-ID|append' "AC-3: normalize/append procedure present" 3

# AC-4: overlap flagging instead of silent merge/discard.
assert_grep "$SKILL" 'duplicate|conflict|overlap' "AC-4: duplicate/conflict flagging present" 2

# AC-5: selection is human-gated; one run = one draft.
assert_grep "$SKILL" 'human confirmation|one run = one draft' "AC-5: human-gated selection present" 1

# AC-6: preparation-only — no spec-file writes into biz-spec.
assert_grep "$SKILL" 'global/biz-spec/REQ-' "AC-6: body does not write specs directly" 1 1

# AC-7: manifest declares 7 skills; REQ-TREESPEC-001 revised to 7.
assert_python "
import tomllib
d = tomllib.load(open('__PROJECT_ROOT__/tree-spec.toml', 'rb'))
skills = d['pipeline']['skills']
assert len(skills) == 7, 'expected 7 skills in manifest, got ' + str(len(skills))
print('OK')
" "AC-7: manifest declares 7 skills"
assert_grep "artifacts/global/biz-spec/REQ-TREESPEC-001.md" 'exactly 7' "AC-7: REQ-TREESPEC-001 says exactly 7"

report_and_exit
