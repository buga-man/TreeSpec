#!/usr/bin/env bash
# Tests for the implement skill — structural assertions only.

. "$(dirname "$0")/../_lib/common.sh"

section "implement — structure"

# 1. File exists.
assert_file_exists "skills/tree-spec/core-capabilities/implement/SKILL.md" "skill file exists"

# 2. Frontmatter.
assert_python "
import re
text = open('__PROJECT_ROOT__/skills/tree-spec/core-capabilities/implement/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
fm = m.group(1)
assert 'id: implement' in fm
assert 'classification: hybrid' in fm, 'classification must be hybrid'
print('OK')
" "frontmatter has required fields"

# 3. Procedure steps.
assert_grep "skills/tree-spec/core-capabilities/implement/SKILL.md" '^### Step 1\. ' "Step 1 (Context) exists"
assert_grep "skills/tree-spec/core-capabilities/implement/SKILL.md" '^### Step 2\. ' "Step 2 (Preconditions) exists"
assert_grep "skills/tree-spec/core-capabilities/implement/SKILL.md" '^### Step 3\. ' "Step 3 (Implementation) exists"
assert_grep "skills/tree-spec/core-capabilities/implement/SKILL.md" '^### Step 4\. ' "Step 4 (Claim/Verify report) exists"
assert_grep "skills/tree-spec/core-capabilities/implement/SKILL.md" '^### Step 5\. ' "Step 5 (Self-checks) exists"
assert_grep "skills/tree-spec/core-capabilities/implement/SKILL.md" '^### Step 6\. ' "Step 6 (Conflicts) exists"
assert_grep "skills/tree-spec/core-capabilities/implement/SKILL.md" '^### Step 7\. ' "Step 7 (Wrap up) exists"

# 4. Sections.
assert_grep "skills/tree-spec/core-capabilities/implement/SKILL.md" '^## Anti-patterns' "anti-patterns section exists"
assert_grep "skills/tree-spec/core-capabilities/implement/SKILL.md" '^## Claim / Verify' "claim/verify section exists"
assert_grep "skills/tree-spec/core-capabilities/implement/SKILL.md" 'Source of truth' "manifest is declared as source of truth"

report_and_exit