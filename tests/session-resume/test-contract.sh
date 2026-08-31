#!/usr/bin/env bash
# Tests for the session-resume skill — contract assertions matching
# specs/REQ-RESUME-001.md. If a check fails here, either the skill
# drifted from its spec, or the spec needs updating.

. "$(dirname "$0")/../_lib/common.sh"

section "session-resume — contract (matches REQ-RESUME-001)"

SKILL=skills/session-resume/SKILL.md

# AC-1: skill file exists at the declared path.
assert_file_exists "$SKILL" "AC-1: skill file exists"

# AC-2: frontmatter declares classification=pure and composition=[].
assert_grep "$SKILL" 'classification: pure' "AC-2: classification=pure present"
assert_grep "$SKILL" 'composition: \[\]' "AC-2: composition=[] present"

# AC-3: side_effects declare only read operations.
assert_grep "$SKILL" '^side_effects:' "AC-3: side_effects section exists"
# Strong negative: no "writes" / "creates a file" / "deletes" mentions.
assert_grep "$SKILL" '\b(writes|creates a file|deletes)\b' "AC-3: no write-side-effect keywords" 1 1

# AC-4: procedure has at least 5 steps.
assert_grep "$SKILL" '^### Step' "AC-4: procedure has at least 5 numbered steps" 5

# AC-5: skill MUST NOT invoke another skill.
assert_grep "$SKILL" 'Do not invoke any skill|MUST NOT invoke|invoke skill|invoke another skill' "AC-5: explicit 'do not invoke' warning present"

# AC-6: README.md instructs agent to run session-resume first.
assert_file_exists "README.md" "AC-6: README.md exists"
assert_grep "README.md" 'session-resume' "AC-6: README.md mentions session-resume"

# AC-7: on missing artifacts/, recommend bootstrap via write-spec.
assert_grep "$SKILL" 'no artifacts/.*bootstrap|bootstrap via .write-spec' "AC-7: recommends bootstrap on fresh project"

report_and_exit