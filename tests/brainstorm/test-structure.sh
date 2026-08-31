#!/usr/bin/env bash
# Tests for the brainstorm skill — structural assertions only.

. "$(dirname "$0")/../_lib/common.sh"

section "brainstorm — structure"

# 1. File exists.
assert_file_exists "skills/brainstorm/SKILL.md" "skill file exists"

# 2. Frontmatter fields.
assert_python "
import re
text = open('__PROJECT_ROOT__/skills/brainstorm/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
assert m, 'frontmatter not found'
fm = m.group(1)
assert 'id: brainstorm' in fm
assert 'classification: stochastic' in fm, 'classification must be stochastic'
assert 'source_doc: path | null' in fm, 'source_doc must be in input contract'
print('OK')
" "frontmatter: id, classification, source_doc present"

# 3. Body has Step 1 (Context), Step 1.5 (source_doc), Step 2 (questions), Step 3 (draft), Step 4 (conflicts), Step 5 (handoff).
assert_grep "skills/brainstorm/SKILL.md" '^### Step 1\. ' "Step 1 exists"
assert_grep "skills/brainstorm/SKILL.md" '^### Step 1\.5\. ' "Step 1.5 (source_doc) exists"
assert_grep "skills/brainstorm/SKILL.md" '^### Step 2\. ' "Step 2 exists"
assert_grep "skills/brainstorm/SKILL.md" '^### Step 3\. ' "Step 3 exists"
assert_grep "skills/brainstorm/SKILL.md" '^### Step 4\. ' "Step 4 exists"
assert_grep "skills/brainstorm/SKILL.md" '^### Step 5\. ' "Step 5 exists"

# 4. Anti-patterns + Claim/Verify.
assert_grep "skills/brainstorm/SKILL.md" '^## Anti-patterns' "anti-patterns section exists"
assert_grep "skills/brainstorm/SKILL.md" '^## Claim / Verify' "claim/verify section exists"

# 5. Manifest declared as source of truth.
assert_grep "skills/brainstorm/SKILL.md" 'Source of truth' "manifest is declared as source of truth"

report_and_exit