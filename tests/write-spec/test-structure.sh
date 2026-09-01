#!/usr/bin/env bash
# Tests for the write-spec skill — structural assertions only.

. "$(dirname "$0")/../_lib/common.sh"

section "write-spec — structure"

# 1. File exists.
assert_file_exists "skills/tree-spec/core-capabilities/write-spec/SKILL.md" "skill file exists"

# 2. Frontmatter.
assert_python "
import re
text = open('__PROJECT_ROOT__/skills/tree-spec/core-capabilities/write-spec/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
fm = m.group(1)
assert 'id: write-spec' in fm
assert 'classification: stochastic' in fm, 'classification must be stochastic'
assert 'Step 0' in text, 'Step 0 (bootstrap) must exist'
assert 'Bootstrap artifacts' in text or 'Bootstrap' in text, 'bootstrap step must be named'
print('OK')
" "frontmatter has required fields; Step 0 (bootstrap) exists"

# 3. Procedure steps.
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" '^### Step 0\. ' "Step 0 (Bootstrap) exists"
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" '^### Step 1\. ' "Step 1 (Context) exists"
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" '^### Step 2\. ' "Step 2 (Validate) exists"
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" '^### Step 3\. ' "Step 3 (Write spec) exists"
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" '^### Step 4\. ' "Step 4 (biz-spec-delta) exists"
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" '^### Step 5\. ' "Step 5 (INDEX.md) exists"
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" '^### Step 6\. ' "Step 6 (Conflicts) exists"
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" '^### Step 7\. ' "Step 7 (Handoff) exists"

# 4. Standard sections.
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" '^## Anti-patterns' "anti-patterns section exists"
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" '^## Claim / Verify' "claim/verify section exists"
assert_grep "skills/tree-spec/core-capabilities/write-spec/SKILL.md" 'Source of truth' "manifest is declared as source of truth"

report_and_exit