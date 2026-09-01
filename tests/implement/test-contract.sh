#!/usr/bin/env bash
# Tests for the implement skill — contract assertions matching
# specs/REQ-IMPL-001.md.

. "$(dirname "$0")/../_lib/common.sh"

section "implement — contract (matches REQ-IMPL-001)"

SKILL=skills/tree-spec/core-capabilities/implement/SKILL.md

# AC-1: file exists.
assert_file_exists "$SKILL" "AC-1: skill file exists"

# AC-2: classification=hybrid.
assert_grep "$SKILL" 'classification: hybrid' "AC-2: classification=hybrid"

# AC-3: report uses canonical report.template.md and fills frontmatter.
assert_grep "$SKILL" 'report\.template\.md' "AC-3: report.template.md referenced"
assert_grep "$SKILL" 'task_id' "AC-3: task_id field mentioned"
assert_grep "$SKILL" 'ac_coverage' "AC-3: ac_coverage field mentioned"
assert_grep "$SKILL" 'scope_adherence' "AC-3: scope_adherence field mentioned"
assert_grep "$SKILL" '^verification:' "AC-3: verification block mentioned"

# AC-4: scope.out is taboo; conflict on creep.
assert_grep "$SKILL" 'scope\.out' "AC-4: scope.out mentioned"
assert_grep "$SKILL" '[Ss]cope creep' "AC-4: scope creep mentioned"
assert_grep "$SKILL" 'conflict-NNN' "AC-4: conflict-NNN mentioned"

# AC-5: missing dep / breaking change → conflict doc.
assert_grep "$SKILL" 'on_missing_dependency|missing dependency' "AC-5: missing dependency → conflict"
assert_grep "$SKILL" 'on_breaking_change|breaking_change' "AC-5: breaking_change → conflict"

# AC-6: anti-pattern for wishful pass without evidence.
assert_grep "$SKILL" 'wishful|without test_refs|without .evidence' "AC-6: anti-pattern forbids wishful pass"

# AC-7: STATUS.md and tasks.md updated.
assert_grep "$SKILL" 'STATUS\.md' "AC-7: STATUS.md referenced"
assert_grep "$SKILL" 'tasks\.md' "AC-7: tasks.md referenced"

report_and_exit