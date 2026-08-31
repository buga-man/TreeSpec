#!/usr/bin/env bash
# Tests for the write-spec skill — contract assertions matching
# specs/REQ-WRITE-001.md.

. "$(dirname "$0")/../_lib/common.sh"

section "write-spec — contract (matches REQ-WRITE-001)"

SKILL=skills/write-spec/SKILL.md

# AC-1: file exists.
assert_file_exists "$SKILL" "AC-1: skill file exists"

# AC-2: classification=stochastic.
assert_grep "$SKILL" 'classification: stochastic' "AC-2: classification=stochastic"

# AC-3: validates every L0 field before writing.
assert_grep "$SKILL" '^### Step 2\. ' "AC-3: validation step (Step 2) exists"
assert_grep "$SKILL" 'id |title |status |type |priority |epic |scope|acceptance_criteria|provenance' "AC-3: validation checks L0 fields" 1

# AC-4: writes spec under global/biz-spec/, updates INDEX.md.
assert_grep "$SKILL" 'artifacts/global/biz-spec' "AC-4: references artifacts/global/biz-spec/"
assert_grep "$SKILL" 'artifacts/INDEX.md' "AC-4: references artifacts/INDEX.md"

# AC-5: creates conflict-NNN.md from template when conflicts.
assert_grep "$SKILL" 'conflict-NNN.md' "AC-5: conflict-NNN.md referenced"
assert_grep "$SKILL" 'conflict-doc.template' "AC-5: conflict-doc.template referenced"

# AC-6: MUST NOT fill L2 fields. The body must explicitly forbid them;
# the frontmatter's `failure_handling:` field is allowed (it's a list of
# error handlers, not a fill instruction).
assert_grep "$SKILL" 'Filling L2 fields' "AC-6: body explicitly forbids L2 fills" 1
assert_grep "$SKILL" '`execution\.\*`' "AC-6: execution.* mentioned as forbidden" 1
assert_grep "$SKILL" '`failure_handling\.\*`' "AC-6: failure_handling.* mentioned as forbidden" 1

# AC-7: creates biz-spec-delta.md in the active epic.
assert_grep "$SKILL" 'biz-spec-delta.md' "AC-7: biz-spec-delta.md referenced"

# AC-8: bootstraps artifacts/ if missing.
assert_grep "$SKILL" 'Step 0.*Bootstrap|test -d artifacts' "AC-8: bootstrap step (Step 0) and check exist"

# AC-9: bootstrap scope is bounded.
assert_grep "$SKILL" '[Bb]ootstrap may write files other than' "AC-9: anti-pattern limits bootstrap scope"

report_and_exit