#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tests/runs/test-exec-modes.sh — AC oracles for REQ-EXEC-003 / EPIC-011
# (execution modes recorded in the .runs/ log: single / best-of-n / consensus)
#
# The log writer is a PASSIVE record store (REQ-EXEC-003 re-scope), so these
# oracles exercise the RECORD LAYER: metadata.mode, seed-distinctness within
# a group, and the chosen/consensus record that links to its attempts. The
# actual execution / seed assignment / output selection stay with the calling
# runtime (external to treespec_log) and are out of scope for this epic.
#
#   AC-1 event_driven  single mode => exactly one record, metadata.mode = single
#   AC-2 event_driven  best-of-n: N attempts + one chosen record linking to them
#   AC-3 event_driven  consensus: N attempts + one consensus record linking to them
#   AC-4 error         duplicate / missing seed in a best-of-n group is rejected
# ════════════════════════════════════════════════════════════════

. "$(dirname "$0")/../_lib/common.sh"

section "exec-modes — REQ-EXEC-003 (EPIC-011)"

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_ROOT="$PROJECT_ROOT/skills/tree-spec"
export PYTHONPATH="$SKILL_ROOT"
export SCRATCH="$(mktemp -d)"
cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

# Resolve bash for wrap-free use (this suite drives `run`, not wrap).
if command -v bash >/dev/null 2>&1; then
    BASH_BIN="$(command -v bash)"
else
    BASH_BIN="/usr/bin/bash"
fi
export BASH_BIN

# AC-1 — single mode writes exactly one record with metadata.mode = single.
assert_python "
import json, os, subprocess, sys
env = os.environ
out = subprocess.run(
    [sys.executable, '-m', 'treespec_log', 'run', 'skill', '--mode', 'single',
     '--epic', 'EPIC-011', '--claim', 'c', '--verify', 'v'],
    cwd=env['SCRATCH'], env=env, capture_output=True, text=True,
)
assert out.returncode == 0, out.stderr
epic = os.path.join(env['SCRATCH'], '.runs', 'EPIC-011')
recs = os.listdir(epic)
assert len(recs) == 1, f'AC-1: expected exactly 1 record, got {len(recs)}'
md = json.load(open(os.path.join(epic, recs[0], 'metadata.json')))
assert md.get('mode') == 'single', f'AC-1: metadata.mode={md.get(\"mode\")!r}'
print('OK')
" "AC-1: single mode => one record, metadata.mode = single (STANDARD)"

# AC-2 — best-of-n: N attempt records + one chosen record linking to them.
assert_python "
import json, os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
ids = []
for i in (1, 2, 3, 4, 5):
    p = run('run', 'skill', '--mode', 'best-of-n', '--seed', str(i),
            '--epic', 'EPIC-011', '--claim', 'c', '--verify', 'v')
    assert p.returncode == 0, p.stderr
    recs = os.listdir(os.path.join(env['SCRATCH'], '.runs', 'EPIC-011'))
    ids.append(recs[-1])
sel = json.dumps({'criteria': 'oracle pass rate', 'chosen_run': ids[1]})
p = run('run', 'skill', '--mode', 'best-of-n', '--chosen', '--attempts', *ids,
        '--selection', sel, '--epic', 'EPIC-011', '--claim', 'c', '--verify', 'v')
assert p.returncode == 0, p.stderr
epic = os.path.join(env['SCRATCH'], '.runs', 'EPIC-011')
recs = os.listdir(epic)
assert len(recs) >= 5, f'AC-2: expected >=5 records, got {len(recs)}'
chosen = json.load(open(os.path.join(epic, recs[-1], 'metadata.json')))
assert chosen.get('chosen') is True, 'AC-2: chosen record flag missing'
assert chosen.get('attempts') == ids, f'AC-2: attempts link mismatch'
assert chosen.get('selection', {}).get('chosen_run') == ids[1], 'AC-2: selection lost'
print('OK')
" "AC-2: best-of-n: N attempts + chosen record linking to them (STANDARD)"

# AC-3 — consensus: N attempt records + one consensus record linking to them.
assert_python "
import json, os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
ids = []
for i in (1, 2, 3, 4, 5):
    p = run('run', 'skill', '--mode', 'consensus', '--seed', str(i),
            '--epic', 'EPIC-011', '--claim', 'c', '--verify', 'v')
    assert p.returncode == 0, p.stderr
    recs = os.listdir(os.path.join(env['SCRATCH'], '.runs', 'EPIC-011'))
    ids.append(recs[-1])
sel = json.dumps({'criteria': 'majority', 'answer': {'x': 1},
                  'tally': {'a': 3}, 'tie_break': 'lowest-seed'})
p = run('run', 'skill', '--mode', 'consensus', '--chosen', '--attempts', *ids,
        '--selection', sel, '--epic', 'EPIC-011', '--claim', 'c', '--verify', 'v')
assert p.returncode == 0, p.stderr
epic = os.path.join(env['SCRATCH'], '.runs', 'EPIC-011')
recs = os.listdir(epic)
assert len(recs) >= 5, f'AC-3: expected >=5 records, got {len(recs)}'
cons = json.load(open(os.path.join(epic, recs[-1], 'metadata.json')))
assert cons.get('mode') == 'consensus', f'AC-3: mode={cons.get(\"mode\")!r}'
assert cons.get('chosen') is True, 'AC-3: chosen record flag missing'
assert cons.get('attempts') == ids, 'AC-3: attempts link mismatch'
assert cons.get('selection', {}).get('tie_break') == 'lowest-seed', 'AC-3: tie-break lost'
print('OK')
" "AC-3: consensus: N attempts + consensus record linking to them (STANDARD)"

# AC-4 — duplicate or missing seed in a best-of-n group is rejected.
assert_python "
import os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
# first attempt: seed 42 ok
assert run('run', 'skill', '--mode', 'best-of-n', '--seed', '42',
           '--epic', 'EPIC-011', '--claim', 'c', '--verify', 'v').returncode == 0
# duplicate seed 42 rejected
p = run('run', 'skill', '--mode', 'best-of-n', '--seed', '42',
        '--epic', 'EPIC-011', '--claim', 'c', '--verify', 'v')
assert p.returncode != 0, 'AC-4: duplicate seed must be rejected'
assert 'seed' in p.stderr.lower(), f'AC-4: stderr must name seed, got: {p.stderr!r}'
# missing seed rejected
p = run('run', 'skill', '--mode', 'best-of-n',
        '--epic', 'EPIC-011', '--claim', 'c', '--verify', 'v')
assert p.returncode != 0, 'AC-4: missing seed must be rejected'
print('OK')
" "AC-4: duplicate / missing seed in best-of-n group rejected (STANDARD)"

report_and_exit
