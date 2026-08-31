#!/usr/bin/env bash
# Tests for the intake skill — structural assertions only.

. "$(dirname "$0")/../_lib/common.sh"

section "intake — structure"

# 1. File exists.
assert_file_exists "skills/intake/SKILL.md" "skill file exists"

# 2. Frontmatter fields.
assert_python "
import re
text = open('__PROJECT_ROOT__/skills/intake/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
assert m, 'frontmatter not found'
fm = m.group(1)
assert 'id: intake' in fm
assert 'classification: hybrid' in fm, 'classification must be hybrid'
assert 'raw_sources: string[]' in fm, 'raw_sources must be in input contract'
print('OK')
" "frontmatter: id, classification, raw_sources present"

# 3. Body has Step 0 (bootstrap), Step 1 (collect), Step 2 (normalize),
#    Step 3 (overlaps), Step 4 (selection), Step 5 (handoff).
assert_grep "skills/intake/SKILL.md" '^### Step 0\. ' "Step 0 (bootstrap buffer) exists"
assert_grep "skills/intake/SKILL.md" '^### Step 1\. ' "Step 1 (collect sources) exists"
assert_grep "skills/intake/SKILL.md" '^### Step 2\. ' "Step 2 (normalize rows) exists"
assert_grep "skills/intake/SKILL.md" '^### Step 3\. ' "Step 3 (check overlaps) exists"
assert_grep "skills/intake/SKILL.md" '^### Step 4\. ' "Step 4 (selection) exists"
assert_grep "skills/intake/SKILL.md" '^### Step 5\. ' "Step 5 (handoff) exists"

# 4. Anti-patterns + Claim/Verify.
assert_grep "skills/intake/SKILL.md" '^## Anti-patterns' "anti-patterns section exists"
assert_grep "skills/intake/SKILL.md" '^## Claim / Verify' "claim/verify section exists"

# 5. Manifest declared as source of truth.
assert_grep "skills/intake/SKILL.md" 'Source of truth' "manifest is declared as source of truth"

report_and_exit
