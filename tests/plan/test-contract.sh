#!/usr/bin/env bash
# Tests for the plan skill — contract assertions matching
# specs/REQ-PLAN-001.md.

. "$(dirname "$0")/../_lib/common.sh"

section "plan — contract (matches REQ-PLAN-001)"

SKILL=skills/plan/SKILL.md

# AC-1: file exists.
assert_file_exists "$SKILL" "AC-1: skill file exists"

# AC-2: classification=hybrid.
assert_grep "$SKILL" 'classification: hybrid' "AC-2: classification=hybrid"

# AC-3: procedure has at least 6 steps.
assert_grep "$SKILL" '^### Step' "AC-3: procedure has at least 6 numbered steps" 6

# AC-4: S/M/L/XL criteria defined.
assert_grep "$SKILL" 'S|M|L|XL' "AC-4: complexity letters present"
assert_grep "$SKILL" 'modules|API|migrations|novelty' "AC-4: complexity dimensions present"

# AC-5: cycle detection in DAG.
assert_grep "$SKILL" 'cycle|cyclic' "AC-5: cycle detection mentioned"

# AC-6: system-analysis.md created when API work.
assert_grep "$SKILL" 'system-analysis.md' "AC-6: system-analysis.md referenced"
assert_grep "$SKILL" 'public API|breaking changes' "AC-6: public API / breaking changes mentioned"

# AC-7: anti-pattern for summing complexity.
assert_grep "$SKILL" 'sum.*complexity|sum of complexity|3..M.*XL' "AC-7: anti-pattern forbids summing complexity" 1 1

report_and_exit