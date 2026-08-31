#!/usr/bin/env bash
# Tests for the verify skill — structural assertions only.

. "$(dirname "$0")/../_lib/common.sh"

section "verify — structure"

# 1. File exists.
assert_file_exists "skills/verify/SKILL.md" "skill file exists"

# 2. Frontmatter.
assert_python "
import re
text = open('__PROJECT_ROOT__/skills/verify/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
fm = m.group(1)
assert 'id: verify' in fm
assert 'classification: pure' in fm, 'classification must be pure'
print('OK')
" "frontmatter: classification=pure"

# 3. Procedure steps.
assert_grep "skills/verify/SKILL.md" '^### Step 1\. ' "Step 1 exists"
assert_grep "skills/verify/SKILL.md" '^### Step 2\. ' "Step 2 exists"
assert_grep "skills/verify/SKILL.md" '^### Step 3\. ' "Step 3 exists"
assert_grep "skills/verify/SKILL.md" '^### Step 4\. ' "Step 4 exists"
assert_grep "skills/verify/SKILL.md" '^### Step 5\. ' "Step 5 exists"
assert_grep "skills/verify/SKILL.md" '^### Step 6\. ' "Step 6 exists"
assert_grep "skills/verify/SKILL.md" '^### Step 7\. ' "Step 7 exists"

# 4. Sections.
assert_grep "skills/verify/SKILL.md" '^## Anti-patterns' "anti-patterns section exists"
assert_grep "skills/verify/SKILL.md" '^## Claim / Verify' "claim/verify section exists"
assert_grep "skills/verify/SKILL.md" 'Source of truth' "manifest is declared as source of truth"

report_and_exit