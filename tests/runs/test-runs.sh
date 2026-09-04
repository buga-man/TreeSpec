#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tests/runs/test-runs.sh — AC oracles for REQ-EXEC-002 / EPIC-010
# (append-only execution-log writer in .runs/)
#
# Each AC is asserted with a self-contained python script via
# assert_python (stdlib only). The runtime resolves because PYTHONPATH
# points at the skill folder (self-contained); the suite runs in a
# scratch dir so it never leaves .runs/ artifacts in the checkout.
#
#   AC-1 event_driven  run writes a .runs/<epic>/<run-id>/ record
#   AC-2 state_driven  each run gets a new id (append-only, no overwrite)
#   AC-3 ubiquitous    metadata.json records reproducibility/mode/retries
#   AC-4 event_driven  validate rejects an incomplete record (exit 1)
#   AC-5 event_driven  treespec-wrap.sh wraps a command and writes a record
#   AC-6 event_driven  treespec-wrap.sh records exit-code on failure
#   AC-7 state_driven  treespec-wrap.sh append-only (two wraps -> two records)
# ════════════════════════════════════════════════════════════════

. "$(dirname "$0")/../_lib/common.sh"

section "runs — REQ-EXEC-002 (EPIC-010)"

# The runtime ships inside the tree-spec skill at
# skills/tree-spec/treespec_log/. PYTHONPATH points at the skill root
# so `python -m treespec_log` resolves. The skill is self-contained:
# copy `skills/tree-spec/` to a consumer repo and the runtime comes with it.
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_ROOT="$PROJECT_ROOT/skills/tree-spec"
export PYTHONPATH="$SKILL_ROOT"
export SCRATCH="$(mktemp -d)"
cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

# On Windows the bare `bash` token resolves to WSL's bash.exe, which
# subprocess.run can't launch from a Windows Python process. Resolve
# bash to its real path once, here, so the AC expressions below can
# use it. sh.exe works on both POSIX and Windows-with-Git.
if command -v bash >/dev/null 2>&1; then
 BASH_BIN="$(command -v bash)"
else
 BASH_BIN="/usr/bin/bash"
fi
export BASH_BIN
export WRAPPER="$SKILL_ROOT/scripts/treespec-wrap.sh"

# ── AC-1 — run writes a complete .runs/ record ──────────────────
# The oracle command is `python -m treespec_log run <skill> --epic <id>`;
# stdout must contain ".runs/" and the record dir must hold the full
# layout. seed.txt must be absent for a non-stochastic skill.
assert_python "
import os, subprocess, sys
out = subprocess.run(
    [sys.executable, '-m', 'treespec_log', 'run', 'brainstorm',
     '--epic', 'EPIC-010', '--input', '{\"q\":\"ideas\"}',
     '--claim', 'Claim part', '--verify', 'Verify part'],
    cwd=os.environ['SCRATCH'], env=os.environ, capture_output=True, text=True,
)
assert out.returncode == 0, out.stderr
rel = out.stdout.splitlines()[0]
assert '.runs/' in rel, f'CLI must print a .runs/ path, got: {rel!r}'
# The CLI prints a path relative to the run cwd (SCRATCH); anchor the
# existence checks there, not to the harness cwd.
path = os.path.join(os.environ['SCRATCH'], rel)
for key in ('input.json', 'output.json', 'claim.md', 'verify.md',
            'exit-code.txt', 'metadata.json'):
    assert os.path.isfile(os.path.join(path, key)), f'missing {key} in {path}'
assert not os.path.isfile(os.path.join(path, 'seed.txt')), \
    'seed.txt must not exist for a pure skill'
print('OK')
" "AC-1: run writes a complete .runs/ record (STANDARD)"

# ── AC-2 — append-only: each run gets a new id ──────────────────
# Running twice must yield two distinct run-ids and two coexisting
# records — nothing is ever overwritten.
assert_python "
import os, subprocess, sys
env = os.environ
def run(n):
    return subprocess.run(
        [sys.executable, '-m', 'treespec_log', 'run', 'skill', '--epic', 'EPIC-010',
         '--input', '{\"n\":%d}' % n, '--claim', 'c', '--verify', 'v'],
        cwd=env['SCRATCH'], env=env, capture_output=True, text=True,
    )
p1, p2 = run(1), run(2)
assert p1.returncode == 0 and p2.returncode == 0, (p1.stderr, p2.stderr)
ids = {l.splitlines()[0] for l in (p1.stdout, p2.stdout)}
assert len(ids) == 2, f'expected 2 distinct run-ids, got {ids}'
count = len([d for d in os.listdir(
    os.path.join(env['SCRATCH'], '.runs', 'EPIC-010'))])
assert count >= 2, f'expected >=2 records, got {count}'
print('OK')
" "AC-2: two runs => two distinct records, no overwrite (STANDARD)"

# ── AC-3 — metadata records reproducibility / mode / retries ────
assert_python "
import glob, json, os, subprocess, sys
env = os.environ
subprocess.run(
    [sys.executable, '-m', 'treespec_log', 'run', 'skill', '--epic', 'EPIC-010',
     '--claim', 'c', '--verify', 'v'],
    cwd=env['SCRATCH'], env=env, capture_output=True, text=True,
)
metas = glob.glob(os.path.join(env['SCRATCH'], '.runs', '*', '*', 'metadata.json'))
assert metas, 'no metadata.json found'
for m in metas:
    d = json.load(open(m))
    for key in ('reproducibility', 'mode', 'retries'):
        assert key in d, f'{m}: missing {key}'
print('OK')
" "AC-3: metadata.json records reproducibility, mode, retries (STANDARD)"

# ── AC-4 — validate rejects an incomplete record (exit 1) ───────
# A clean store validates (exit 0); dropping a required key makes
# `runs validate` exit 1.
assert_python "
import os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
# clean store validates (exit 0).
run('run', 'skill', '--epic', 'EPIC-010', '--claim', 'c', '--verify', 'v')
v = run('runs', 'validate', '--path', '.runs')
assert v.returncode == 0, f'clean store must validate, got {v.returncode}\\n{v.stderr}'
# corrupt: drop a required key.
recs = os.listdir(os.path.join(env['SCRATCH'], '.runs', 'EPIC-010'))
os.remove(os.path.join(env['SCRATCH'], '.runs', 'EPIC-010', recs[0], 'verify.md'))
v = run('runs', 'validate', '--path', '.runs')
assert v.returncode == 1, f'incomplete record must fail validate with exit 1, got {v.returncode}'
print('OK')
" "AC-4: validate rejects incomplete record (exit 1) (STANDARD)"

# ── AC-5 — treespec-wrap.sh writes a record for a successful command ─
# Single bash invocation → one .runs/ record with input.json holding
# argv, output.json holding captured stdout, exit-code.txt = 0.
assert_python "
import json, os, subprocess, sys
env = os.environ
out = subprocess.run(
    [env['BASH_BIN'], env['WRAPPER'],
     '--epic', 'EPIC-010',
     '--claim', 'wrap AC-5', '--verify', 'echoed hello',
     '--', 'echo', 'hello-from-wrap'],
    cwd=env['SCRATCH'], env=env, capture_output=True, text=True,
)
assert out.returncode == 0, f'rc={out.returncode}\\nstdout={out.stdout!r}\\nstderr={out.stderr!r}'
rec_root = os.path.join(env['SCRATCH'], '.runs', 'EPIC-010')
runs = sorted(os.listdir(rec_root))
assert runs, 'no record written'
rec = os.path.join(rec_root, runs[-1])
inp = json.load(open(os.path.join(rec, 'input.json')))
assert inp['argv'][-1] == 'hello-from-wrap', inp
outp = json.load(open(os.path.join(rec, 'output.json')))
assert 'hello-from-wrap' in outp['stdout'], outp
assert outp['exit_code'] == 0, outp
assert open(os.path.join(rec, 'exit-code.txt')).read().strip() == '0'
assert 'wrap AC-5' in open(os.path.join(rec, 'claim.md')).read()
assert 'echoed hello' in open(os.path.join(rec, 'verify.md')).read()
print('OK')
" "AC-5: treespec-wrap.sh writes a record (STANDARD)"

# ── AC-6 — treespec-wrap.sh records exit-code on failure ────────
# The wrapped command's exit code must propagate both to the record
# (exit-code.txt, output.json.exit_code) AND to the wrapper itself.
assert_python "
import json, os, subprocess, sys
env = os.environ
out = subprocess.run(
    [env['BASH_BIN'], env['WRAPPER'],
     '--epic', 'EPIC-010',
     '--claim', 'wrap AC-6', '--verify', 'expected failure',
     '--reproducibility', 'best-effort',
     '--', 'python', '-c', 'import sys; sys.exit(7)'],
    cwd=env['SCRATCH'], env=env, capture_output=True, text=True,
)
assert out.returncode == 7, f'wrapper exit must propagate, got {out.returncode}; out={out.stdout!r}; err={out.stderr!r}'
rec_root = os.path.join(env['SCRATCH'], '.runs', 'EPIC-010')
runs = sorted(os.listdir(rec_root))
rec = os.path.join(rec_root, runs[-1])
outp = json.load(open(os.path.join(rec, 'output.json')))
assert outp['exit_code'] == 7, outp
assert open(os.path.join(rec, 'exit-code.txt')).read().strip() == '7'
print('OK')
" "AC-6: treespec-wrap.sh records exit-code on failure (STANDARD)"

# ── AC-7 — wrap is append-only: two wraps → two records ─────────
assert_python "
import os, subprocess, sys
env = os.environ
def wrap(n):
    return subprocess.run(
        [env['BASH_BIN'], env['WRAPPER'],
         '--epic', 'EPIC-010',
         '--claim', f'wrap {n}', '--verify', f'wrap {n} verify',
         '--', 'echo', str(n)],
        cwd=env['SCRATCH'], env=env, capture_output=True, text=True,
    )
w1, w2 = wrap(1), wrap(2)
assert w1.returncode == 0 and w2.returncode == 0, (w1.stderr, w2.stderr)
rec_root = os.path.join(env['SCRATCH'], '.runs', 'EPIC-010')
runs = sorted(os.listdir(rec_root))
assert len(runs) >= 2, f'expected >=2 records under {rec_root}, got {runs}'
print('OK')
" "AC-7: treespec-wrap.sh is append-only (STANDARD)"

# Reflection digest (owner-directed, EPIC-013): `runs list <epic>` shows
# every record of the epic — sequential AND hash ids alike — with skill,
# exit code, mode and the first claim line. Failing runs must be visible.
assert_python "
import os, subprocess, sys
env = os.environ
def cli(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
p = cli('run', 'refl-skill', '--epic', 'EPIC-REFL', '--claim', 'first claim line', '--exit-code', '0')
assert p.returncode == 0, f'digest: run failed: {p.stderr!r}'
p = cli('run', 'refl-skill', '--epic', 'EPIC-REFL', '--claim', 'second claim line', '--exit-code', '1')
assert p.returncode == 0, f'digest: failing run must still be recorded: {p.stderr!r}'
p = cli('run', 'refl-skill', '--epic', 'EPIC-REFL', '--id-strategy', 'hash',
        '--input', '{\"x\": 1}', '--claim', 'hash claim line')
assert p.returncode == 0, f'digest: hash run failed: {p.stderr!r}'
p = cli('runs', 'list', 'EPIC-REFL')
assert p.returncode == 0, f'runs list <epic> failed: {p.stderr!r}'
lines = [l for l in p.stdout.splitlines() if l.strip()]
assert len(lines) == 3, f'digest: expected 3 records, got {len(lines)}: {p.stdout!r}'
assert any('exit=0' in l and 'first claim line' in l for l in lines), f'digest: first record missing/wrong: {lines}'
assert any('exit=1' in l and 'second claim line' in l for l in lines), f'digest: failing run must be visible: {lines}'
assert any('hash claim line' in l for l in lines), f'digest: hash-id record must be visible: {lines}'
assert all('skill=refl-skill' in l and 'mode=single' in l for l in lines), f'digest: skill/mode fields missing: {lines}'
print('OK')
" "reflection digest: runs list <epic> shows sequential + hash records (STANDARD)"

report_and_exit
