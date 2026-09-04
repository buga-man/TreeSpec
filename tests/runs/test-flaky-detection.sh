#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tests/runs/test-flaky-detection.sh — AC oracles for REQ-EXEC-004 / EPIC-012
# (flaky detection: rate aggregation, quarantine store, verdict exemption,
# lift rules)
#
# The retry loop lives in the AGENT runtime (default 3 cycles); these
# oracles exercise the RECORD LAYER exactly like test-exec-modes.sh: the
# "agent" runs a synthetic flaky skill (tests/fixtures/flaky-skill.sh),
# records each attempt via `run`, then drives `runs report` and
# `quarantine release`.
#
#   AC-1 event_driven  rate > tolerance => quarantine file + `flaky: known issue`
#   AC-2 state_driven  quarantined skill does not block: report exits 0
#   AC-3 event_driven  N = 3 clean epics => release (`--clean 3`)
#   AC-4 unwanted      a never-failing skill is never quarantined
#   AC-5 event_driven  30-day time-out releases; a young entry does not
#   AC-6 event_driven  manual clear (`--manual`) releases unconditionally
# ════════════════════════════════════════════════════════════════

. "$(dirname "$0")/../_lib/common.sh"

section "flaky-detection — REQ-EXEC-004 (EPIC-012)"

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_ROOT="$PROJECT_ROOT/skills/tree-spec"
export PYTHONPATH="$SKILL_ROOT"
export SCRATCH="$(mktemp -d)"
export FIXTURES="$PROJECT_ROOT/tests/fixtures"
cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

# Resolve bash for wrap-free use (this suite drives `run`, not wrap).
# On Windows the bare `bash` on PATH may be WSL, which cannot exec the
# fixture — pin the shell that runs this test instead.
if command -v bash >/dev/null 2>&1; then
  BASH_BIN="$(command -v bash)"
else
  BASH_BIN="/usr/bin/bash"
fi
export BASH_BIN

# AC-1 — rate > tolerance => quarantine file + `flaky: known issue`.
assert_python "
import json, os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
# agent retry protocol: 3 cycles of the synthetic flaky skill (fails 1st run)
state = os.path.join(env['SCRATCH'], 'flaky-state')
codes = []
for i in range(3):
    p = subprocess.run([env['BASH_BIN'],
                        os.path.join(env['FIXTURES'], 'flaky-skill.sh'), state],
                       capture_output=True)
    codes.append(p.returncode)
    assert run('run', 'flaky-skill', '--epic', 'EPIC-012T',
               '--exit-code', str(p.returncode), '--claim', 'c', '--verify', 'v').returncode == 0
assert codes == [1, 0, 0], f'AC-1: fixture must fail exactly once, got {codes}'
# verdict report: quarantines the skill (oracle: output contains 'quarantine')
p = run('runs', 'report', 'EPIC-012T')
assert p.returncode == 0, f'AC-1: report failed: {p.stderr!r}'
assert 'quarantine' in p.stdout, f'AC-1: stdout must mention quarantine, got: {p.stdout!r}'
q = os.path.join(env['SCRATCH'], '.runs', 'quarantine', 'flaky-skill.json')
assert os.path.isfile(q), 'AC-1: quarantine file not written'
entry = json.load(open(q))
assert entry['rate'] == {'failed_runs': 1, 'total_runs': 3}, f\"AC-1: rate={entry.get('rate')}\"
# chosen records never count toward total_runs (feasibility risk #1):
# two best-of-n attempts + one chosen record => report must say 0/2
assert run('run', 'mode-skill', '--epic', 'EPIC-012T', '--mode', 'best-of-n',
           '--seed', '1', '--claim', 'c', '--verify', 'v').returncode == 0
assert run('run', 'mode-skill', '--epic', 'EPIC-012T', '--mode', 'best-of-n',
           '--seed', '2', '--claim', 'c', '--verify', 'v').returncode == 0
ids = []
for name in sorted(os.listdir(os.path.join(env['SCRATCH'], '.runs', 'EPIC-012T'))):
    md = json.load(open(os.path.join(env['SCRATCH'], '.runs', 'EPIC-012T', name, 'metadata.json')))
    if md.get('mode') == 'best-of-n' and not md.get('chosen'):
        ids.append(name)
assert run('run', 'mode-skill', '--epic', 'EPIC-012T', '--mode', 'best-of-n',
           '--chosen', '--attempts', *ids, '--claim', 'c', '--verify', 'v').returncode == 0
p = run('runs', 'report', 'EPIC-012T')
assert 'ok: mode-skill 0/2' in p.stdout, f'AC-1: chosen record must not count (want 0/2), got: {p.stdout!r}'
print('OK')
" "AC-1: rate > tolerance => quarantine file + flaky verdict (STANDARD)"

# AC-2 — a quarantined skill does not block the epic: report exits 0.
assert_python "
import os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
p = run('runs', 'report', 'EPIC-012T')   # flaky-skill already quarantined by AC-1
assert p.returncode == 0, f'AC-2: report must exit 0 with a quarantined skill: {p.stderr!r}'
assert 'flaky: known issue' in p.stdout, f'AC-2: verdict line missing: {p.stdout!r}'
assert 'verdict: EPIC-012T: flaky: known issue' in p.stdout, f'AC-2: epic verdict missing: {p.stdout!r}'
print('OK')
" "AC-2: quarantined skill does not block the epic (exit 0) (STANDARD)"

# AC-3 — N = 3 consecutive clean epics => release.
assert_python "
import os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
q = os.path.join(env['SCRATCH'], '.runs', 'quarantine', 'flaky-skill.json')
assert os.path.isfile(q), 'AC-3: precondition — quarantine file must exist'
p = run('quarantine', 'release', '--id', 'flaky-skill', '--clean', '3')
assert p.returncode == 0, f'AC-3: release --clean 3 failed: {p.stderr!r}'
assert 'released: flaky-skill (clean-epics:3)' in p.stdout, f'AC-3: release line missing: {p.stdout!r}'
assert not os.path.isfile(q), 'AC-3: quarantine file must be deleted'
print('OK')
" "AC-3: N = 3 clean epics => quarantine released (STANDARD)"

# AC-4 — a never-failing skill is never added to quarantine.
assert_python "
import os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
for i in range(3):   # pure skill: 3 passing attempts
    assert run('run', 'pure-skill', '--epic', 'EPIC-012P',
               '--exit-code', '0', '--claim', 'c', '--verify', 'v').returncode == 0
p = run('runs', 'report', 'EPIC-012P')
assert p.returncode == 0, f'AC-4: report failed: {p.stderr!r}'
assert 'ok: pure-skill 0/3' in p.stdout, f'AC-4: clean line missing: {p.stdout!r}'
qdir = os.path.join(env['SCRATCH'], '.runs', 'quarantine')
assert not (os.path.isdir(qdir) and any(f.startswith('pure-skill') for f in os.listdir(qdir))), \
    'AC-4: a never-failing skill must never be quarantined'
print('OK')
" "AC-4 (unwanted): never-failing skill is never quarantined (STANDARD)"

# AC-5 — 30-day time-out releases; a young entry does not.
assert_python "
import json, os, subprocess, sys
from datetime import datetime, timedelta, timezone
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
qdir = os.path.join(env['SCRATCH'], '.runs', 'quarantine')
os.makedirs(qdir, exist_ok=True)
def seed(skill, days_ago):
    path = os.path.join(qdir, skill + '.json')
    json.dump({'skill': skill,
               'quarantined_at': (datetime.now(timezone.utc) - timedelta(days=days_ago)).isoformat(),
               'clean_epics': 0, 'flaky_tolerance': 0.0,
               'rate': {'failed_runs': 1, 'total_runs': 3},
               'epic': 'EPIC-012T', 'runs': []}, open(path, 'w'))
    return path
# young entry (2 days): plain release must be refused
young = seed('young-skill', 2)
p = run('quarantine', 'release', '--id', 'young-skill')
assert p.returncode != 0, 'AC-5: a <30-day-old quarantine must not auto-release'
assert os.path.isfile(young), 'AC-5: young entry must survive'
# aged entry (31 days): plain release goes through with reason timeout
aged = seed('aged-skill', 31)
p = run('quarantine', 'release', '--id', 'aged-skill')
assert p.returncode == 0, f'AC-5: time-out release failed: {p.stderr!r}'
assert 'released: aged-skill (timeout)' in p.stdout, f'AC-5: reason missing: {p.stdout!r}'
assert not os.path.isfile(aged), 'AC-5: aged entry must be deleted'
print('OK')
" "AC-5: 30-day time-out releases, young entry does not (STANDARD)"

# AC-6 — manual clear releases unconditionally.
assert_python "
import json, os, subprocess, sys
from datetime import datetime, timezone
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
qdir = os.path.join(env['SCRATCH'], '.runs', 'quarantine')
os.makedirs(qdir, exist_ok=True)
path = os.path.join(qdir, 'manual-skill.json')
json.dump({'skill': 'manual-skill',
           'quarantined_at': datetime.now(timezone.utc).isoformat(),
           'clean_epics': 0, 'flaky_tolerance': 0.0,
           'rate': {'failed_runs': 1, 'total_runs': 3},
           'epic': 'EPIC-012T', 'runs': []}, open(path, 'w'))
p = run('quarantine', 'release', '--id', 'manual-skill', '--manual')
assert p.returncode == 0, f'AC-6: manual release failed: {p.stderr!r}'
assert 'released: manual-skill (manual)' in p.stdout, f'AC-6: reason missing: {p.stdout!r}'
assert not os.path.isfile(path), 'AC-6: entry must be deleted'
# releasing an absent skill fails loudly
p = run('quarantine', 'release', '--id', 'manual-skill', '--manual')
assert p.returncode != 0, 'AC-6: releasing a non-quarantined skill must fail'
print('OK')
" "AC-6: manual clear releases unconditionally (STANDARD)"

report_and_exit
