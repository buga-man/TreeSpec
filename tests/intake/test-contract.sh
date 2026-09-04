#!/usr/bin/env bash
# Tests for the intake skill — contract assertions matching
# tests/_fixtures/biz-spec/REQ-INTAKE-001.md (committed fixture; mirrors
# the real spec at artifacts/global/biz-spec/REQ-INTAKE-001.md so this
# test runs standalone without the artifacts/ subtree being checked in).

. "$(dirname "$0")/../_lib/common.sh"

section "intake — contract (matches REQ-INTAKE-001)"

SKILL=skills/tree-spec/core-capabilities/intake/SKILL.md

# AC-1: intake buffer exists with the candidate schema.
assert_file_exists "tests/_fixtures/intake-buffer/REQUIREMENTS.md" "AC-1: intake buffer exists"
assert_grep "tests/_fixtures/intake-buffer/REQUIREMENTS.md" 'Cand-ID' "AC-1: candidate table has Cand-ID column"

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

# AC-7: manifest declares 8 core capabilities (plus tree-spec + init wrappers).
# EPIC-004 (one-skill style) moved skills under skills/tree-spec/core-capabilities/
# and added init as a bootstrap entry. EPIC-010 T-04 (2026-09-04) added `log`
# as the 8th core capability (cross-cutting; any stage may invoke it).
# REQ-TREESPEC-001 says "exactly 8" since rev 5; see the revision history
# and the marker note in EPIC-005 docs/conflict-002.md.
assert_python "
import tomllib
d = tomllib.load(open('__PROJECT_ROOT__/tree-spec.toml', 'rb'))
skills = d['pipeline']['skills']
core = {'intake', 'session-resume', 'brainstorm', 'write-spec', 'plan', 'implement', 'verify', 'log'}
declared = set(skills.keys())
missing = core - declared
extra = declared - core - {'tree-spec', 'init'}
assert not missing, ('core capabilities missing from [pipeline.skills]: ' + str(sorted(missing)))
assert not extra, ('unexpected non-core skills in [pipeline.skills]: ' + str(sorted(extra)))
print('OK')
" "AC-7: manifest declares the 8 core capabilities (+ tree-spec, init)"
assert_grep "tests/_fixtures/biz-spec/REQ-TREESPEC-001.md" 'exactly 8' "AC-7: REQ-TREESPEC-001 says exactly 8 (core capability skills, post-EPIC-010 T-04)"

report_and_exit
