#!/usr/bin/env bash
# Tests for the log capability — contract assertions matching the
# SKILL.md procedure and REQ-TREESPEC-001 rev 5 (log as the 8th core
# capability). There is no dedicated REQ-* for log; the contract is
# owned by REQ-TREESPEC-001 (manifest invariant) + REQ-EXEC-002
# (runtime contract — see tests/runs/test-runs.sh).

. "$(dirname "$0")/../_lib/common.sh"

section "log — contract (matches REQ-TREESPEC-001 rev 5 + REQ-EXEC-002)"

SKILL=skills/tree-spec/core-capabilities/log/SKILL.md
RUNTIME_DIR=skills/tree-spec/treespec_log
BASH_WRAPPER=skills/tree-spec/scripts/treespec-wrap.sh

# AC-1: skill file exists at the path the manifest declares.
assert_file_exists "$SKILL" "AC-1: SKILL.md exists at manifest-declared path"

# AC-2: manifest declares log as a [pipeline.skills.*] entry with
# all four classification fields (REQ-TREESPEC-001 invariant;
# verified mechanically by tests/manifest/test-rules.sh
# ASSERT-MANIFEST-017/018, asserted here for redundancy).
assert_python "
import tomllib
d = tomllib.load(open('__PROJECT_ROOT__/tree-spec.toml', 'rb'))
log = d['pipeline']['skills']['log']
for field in ('file', 'classification', 'reproducibility',
              'execution_mode', 'flaky_tolerance', 'stage'):
    assert field in log, f'log missing {field}'
assert log['file'] == 'core-capabilities/log/SKILL.md'
assert log['classification'] == 'pure'
assert log['stage'] == 'any'
print('OK')
" "AC-2: [pipeline.skills.log] declares all six required fields"

# AC-3: SKILL.md documents both modes (run + wrap).
assert_grep "$SKILL" 'mode.*run.*wrap|run.*and.*wrap' "AC-3: SKILL.md documents both modes (run + wrap)" 1
assert_grep "$SKILL" 'mode.*wrap' "AC-3: wrap mode entry is documented"
assert_grep "$SKILL" 'mode.*run' "AC-3: run mode entry is documented"

# AC-4: SKILL.md tells the agent when claim is intent vs verify is observation.
assert_grep "$SKILL" 'claim.*before|claim is intent|intent.*before' "AC-4: claim described as intent (before execution)" 1
assert_grep "$SKILL" 'verify.*after|verify is observation|observation.*after' "AC-4: verify described as observation (after execution)" 1

# AC-5: SKILL.md is honest about append-only — wraps agent's mental model.
assert_grep "$SKILL" 'append-only' "AC-5: append-only property is documented" 1
assert_grep "$SKILL" 'audit' "AC-5: audit trail is documented as a goal"

# AC-6: SKILL.md points to the runtime that actually does the work.
assert_grep "$SKILL" 'treespec_log|runs\.py' "AC-6: SKILL.md names the runtime"
assert_grep "$SKILL" 'treespec-wrap\.sh' "AC-6: SKILL.md names the bash wrapper"

# AC-7: SKILL.md propagates the self-containment property to the agent.
assert_grep "$SKILL" 'PYTHONPATH.*skill|self-contained|copy.*skill' "AC-7: self-containment is documented" 1

# AC-8: SKILL.md anti-patterns forbid the obvious footguns.
assert_grep "$SKILL" 'PYTHONPATH.*without|without.*PYTHONPATH' "AC-8: anti-pattern: skipping PYTHONPATH" 1
assert_grep "$SKILL" 'append-only|never.*edit|edit.*record' "AC-8: anti-pattern: editing records" 1

# AC-9: runtime exists and is wired (regression against T-04 deletion).
assert_dir_exists "$RUNTIME_DIR" "AC-9: treespec_log Python package exists inside the skill"

# AC-10: bash wrapper exists.
assert_file_exists "$BASH_WRAPPER" "AC-10: treespec-wrap.sh entry point exists"

report_and_exit