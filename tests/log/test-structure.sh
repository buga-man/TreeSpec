#!/usr/bin/env bash
# Tests for the log capability — structural assertions only.
# log is the 8th core capability of the tree-spec skill (added in
# EPIC-010 T-04, activated 2026-09-04, REQ-TREESPEC-001 rev 5).
# It's cross-cutting: any stage may invoke it.

. "$(dirname "$0")/../_lib/common.sh"

section "log — structure"

# 1. File exists.
assert_file_exists "skills/tree-spec/core-capabilities/log/SKILL.md" "skill file exists"

# 2. Frontmatter has the four classification fields (REQ-EXEC-001 +
# REQ-TREESPEC-001 invariant: every [pipeline.skills.*] declares all four).
assert_python "
import re
text = open('__PROJECT_ROOT__/skills/tree-spec/core-capabilities/log/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
fm = m.group(1)
assert 'id: log' in fm, 'id must be log'
assert 'classification: pure' in fm, 'classification must be pure'
assert 'reproducibility:' in fm, 'reproducibility field must be declared'
assert 'execution_mode:' in fm, 'execution_mode field must be declared'
assert 'flaky_tolerance:' in fm, 'flaky_tolerance field must be declared'
assert 'stage: any' in fm, 'log is cross-cutting (stage: any)'
print('OK')
" "frontmatter declares all four classification fields + stage=any"

# 3. Procedure steps.
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" '^### Step 1\. ' "Step 1 (Pick the mode) exists"
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" '^### Step 2\. ' "Step 2 (Pick the epic) exists"
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" '^### Step 3\. ' "Step 3 (Compose claim/verify) exists"
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" '^### Step 4\. ' "Step 4 (Execute + write) exists"
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" '^### Step 5\. ' "Step 5 (Reference the record) exists"

# 4. Standard sections.
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" '^## Anti-patterns' "anti-patterns section exists"
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" '^## Claim / Verify' "claim/verify section exists"
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" 'Source of truth' "manifest is declared as source of truth"

# 5. Two modes documented.
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" 'mode.*run|mode.*wrap' "Step 1 distinguishes run vs wrap"
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" 'python -m treespec_log run' "run mode is the python -m treespec_log run entry"
assert_grep "skills/tree-spec/core-capabilities/log/SKILL.md" 'treespec-wrap\.sh' "wrap mode is the treespec-wrap.sh entry"

# 6. Manifest registration is consistent (string comparison via python
# because assert_toml_field's expected-string comparison is finicky with
# paths that have slashes — easier to read this way).
assert_python "
import tomllib
d = tomllib.load(open('__PROJECT_ROOT__/tree-spec.toml', 'rb'))
log = d['pipeline']['skills']['log']
assert log['file'] == 'core-capabilities/log/SKILL.md', log['file']
assert log['classification'] == 'pure', log['classification']
assert log['reproducibility'] == 'strict', log['reproducibility']
assert log['execution_mode'] == 'single', log['execution_mode']
assert log['flaky_tolerance'] == 0.0, log['flaky_tolerance']
assert log['stage'] == 'any', log['stage']
print('OK')
" "manifest [pipeline.skills.log] registration matches all 6 fields"

report_and_exit