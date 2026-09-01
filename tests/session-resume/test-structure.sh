#!/usr/bin/env bash
# Tests for the session-resume skill — structural assertions only.
# Contract assertions (matching REQ-RESUME-001) are in test-contract.sh.

. "$(dirname "$0")/../_lib/common.sh"

section "session-resume — structure"

# 1. File exists at the path declared in tree-spec.toml.
assert_file_exists "skills/tree-spec/core-capabilities/session-resume/SKILL.md" "skill file exists"

# 2. Frontmatter opens with `---` (we use a YAML-aware check).
assert_python "
import re
text = open('__PROJECT_ROOT__/skills/tree-spec/core-capabilities/session-resume/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
assert m, 'frontmatter not found'
fm = m.group(1)
assert 'id: session-resume' in fm, 'id field missing or wrong'
assert 'version:' in fm, 'version field missing'
assert 'phase: 0' in fm, 'phase field missing'
assert 'classification: pure' in fm, 'classification must be pure'
assert 'composition: []' in fm, 'composition must be empty (no implicit invocation)'
print('OK')
" "frontmatter has required fields" "see CON-09 contract"

# 3. Frontmatter declares stage = any.
assert_grep "skills/tree-spec/core-capabilities/session-resume/SKILL.md" '^stage: any' "stage is \"any\" (not stage 1–4)"

# 4. Body has Step 1 (find active epic), Step 2 (read state), Step 3 (manifest), Step 4 (decision), Step 5 (output).
assert_grep "skills/tree-spec/core-capabilities/session-resume/SKILL.md" '^### Step 1\. ' "procedure: Step 1 exists"
assert_grep "skills/tree-spec/core-capabilities/session-resume/SKILL.md" '^### Step 2\. ' "procedure: Step 2 exists"
assert_grep "skills/tree-spec/core-capabilities/session-resume/SKILL.md" '^### Step 3\. ' "procedure: Step 3 exists"
assert_grep "skills/tree-spec/core-capabilities/session-resume/SKILL.md" '^### Step 4\. ' "procedure: Step 4 exists"
assert_grep "skills/tree-spec/core-capabilities/session-resume/SKILL.md" '^### Step 5\. ' "procedure: Step 5 exists"

# 5. Body has Anti-patterns section.
assert_grep "skills/tree-spec/core-capabilities/session-resume/SKILL.md" '^## Anti-patterns' "anti-patterns section exists"

# 6. Body has Claim/Verify section.
assert_grep "skills/tree-spec/core-capabilities/session-resume/SKILL.md" '^## Claim / Verify' "claim/verify section exists"

# 7. Source-of-truth block references the manifest.
assert_grep "skills/tree-spec/core-capabilities/session-resume/SKILL.md" 'Source of truth' "manifest is declared as source of truth"

report_and_exit