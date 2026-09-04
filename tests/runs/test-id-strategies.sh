#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tests/runs/test-id-strategies.sh — AC oracles for REQ-EXEC-005 / EPIC-013
# (id strategies: hash collision chaining, sequential monotonicity,
# purity guard via `validate`)
#
# The record layer is exercised end-to-end like test-flaky-detection.sh:
# the "agent" drives `treespec_log run` with --id-strategy/--input and
# `treespec_log validate` against a synthetic manifest. No skill execution
# happens — treespec_log is a passive record store.
#
#   AC-1 event_driven  hash: identical input → same chain (base id, input_hash)
#   AC-2 state_driven  repeat run probes the next slot (<base>-2/-3), append-only
#   AC-3 event_driven  sequential: unique monotonically increasing ids
#   AC-4 unwanted      validate rejects hash for a non-pure skill (exit 1)
# ════════════════════════════════════════════════════════════════

. "$(dirname "$0")/../_lib/common.sh"

section "id-strategies — REQ-EXEC-005 (EPIC-013)"

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_ROOT="$PROJECT_ROOT/skills/tree-spec"
export PYTHONPATH="$SKILL_ROOT"
export SCRATCH="$(mktemp -d)"
cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

# AC-1 — hash: two runs with identical input belong to the same chain.
assert_python "
import json, os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
IN = '{\"x\": 1}'
p1 = run('run', 'pure-skill', '--epic', 'EPIC-013T', '--id-strategy', 'hash', '--input', IN)
assert p1.returncode == 0, f'AC-1: first hash run failed: {p1.stderr!r}'
assert 'input_hash=' in p1.stdout, f'AC-1: stdout must carry input_hash=: {p1.stdout!r}'
p2 = run('run', 'pure-skill', '--epic', 'EPIC-013T', '--id-strategy', 'hash', '--input', IN)
assert p2.returncode == 0, f'AC-1: second hash run failed: {p2.stderr!r}'
assert 'input_hash=' in p2.stdout, f'AC-1: stdout must carry input_hash=: {p2.stdout!r}'
def field(out, key):
    for line in out.splitlines():
        if line.startswith(key + ':'):
            return line.split(':', 1)[1].strip()
    raise AssertionError(f'{key} not found in {out!r}')
id1, id2 = field(p1.stdout, 'run-id'), field(p2.stdout, 'run-id')
h1 = p1.stdout.split('input_hash=')[1].split()[0]
h2 = p2.stdout.split('input_hash=')[1].split()[0]
assert h1 == h2, f'AC-1: identical input must give one digest, got {h1} vs {h2}'
assert id1 == f'EPIC-013T-{h1}', f'AC-1: first id must be the base, got {id1}'
assert id2 == f'{id1}-2', f'AC-1: second id must be the probed slot <base>-2, got {id2}'
for rid in (id1, id2):
    meta = json.load(open(os.path.join(env['SCRATCH'], '.runs', 'EPIC-013T', rid, 'metadata.json')))
    assert meta.get('input_hash') == h1 and meta.get('id_strategy') == 'hash', \
        f'AC-1: metadata must link the chain for {rid}: {meta}'
print('OK')
" "AC-1: hash — identical input → same chain (base id + input_hash) (STANDARD)"

# AC-2 — state_driven: a third run probes <base>-3; existing records untouched.
assert_python "
import hashlib, json, os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
IN = '{\"x\": 1}'
base_dir = os.path.join(env['SCRATCH'], '.runs', 'EPIC-013T')
def snapshot():
    snap = {}
    for rid in sorted(os.listdir(base_dir)):
        rdir = os.path.join(base_dir, rid)
        if not os.path.isdir(rdir):
            continue
        for name in sorted(os.listdir(rdir)):
            with open(os.path.join(rdir, name), 'rb') as fh:
                snap[rid + '/' + name] = hashlib.sha256(fh.read()).hexdigest()
    return snap
before = snapshot()
p3 = run('run', 'pure-skill', '--epic', 'EPIC-013T', '--id-strategy', 'hash', '--input', IN)
assert p3.returncode == 0, f'AC-2: third hash run failed: {p3.stderr!r}'
id3 = [l.split(':', 1)[1].strip() for l in p3.stdout.splitlines() if l.startswith('run-id:')][0]
heads = sorted(d for d in os.listdir(base_dir) if not d.endswith(('-2', '-3')))
assert len(heads) == 1, f'AC-2: expected one chain head, got {heads}'
assert id3 == heads[0] + '-3', f'AC-2: third run must probe <base>-3, got {id3}'
assert snapshot() == before | {**{k: v for k, v in snapshot().items() if k.startswith(id3)}}, \
    'AC-2: pre-existing records must be byte-identical (append-only)'
print('OK')
" "AC-2: repeat hash run probes next slot; existing records untouched (STANDARD)"

# AC-3 — sequential (default): unique, monotonically increasing ids.
assert_python "
import os, subprocess, sys
env = os.environ
def run(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
ids = []
for i in range(3):
    p = run('run', 'seq-skill', '--epic', 'EPIC-013S')
    assert p.returncode == 0, f'AC-3: sequential run {i} failed: {p.stderr!r}'
    ids.append([l.split(':', 1)[1].strip() for l in p.stdout.splitlines() if l.startswith('run-id:')][0])
assert len(set(ids)) == 3, f'AC-3: ids must be unique, got {ids}'
nums = [int(r.rsplit('-', 1)[1]) for r in ids]
assert nums == sorted(nums) and all(b > a for a, b in zip(nums, nums[1:])), \
    f'AC-3: ids must be monotonically increasing, got {ids}'
assert 'EPIC-013S-0002' in ids, f'AC-3: counter format <epic>-NNNN expected, got {ids}'
print('OK')
" "AC-3: sequential — unique monotonically increasing ids (STANDARD)"

# AC-4 — validate rejects hash for a non-pure skill; allows pure; loud on unknown.
assert_python "
import os, subprocess, sys
env = os.environ
def val(*a):
    return subprocess.run([sys.executable, '-m', 'treespec_log', *a],
                          cwd=env['SCRATCH'], env=env, capture_output=True, text=True)
manifest = os.path.join(env['SCRATCH'], 'm.toml')
with open(manifest, 'w') as fh:
    fh.write(
        '[kernel]\nid_strategy = \"hash\"\n\n'
        '[pipeline.skills.pure-skill]\npure = true\n\n'
        '[pipeline.skills.stochastic-skill]\nflaky_tolerance = 0.1\n'
    )
p = val('validate', '--manifest', manifest, '--skill', 'stochastic-skill')
assert p.returncode == 1, f'AC-4: non-pure skill must be rejected (exit 1), got {p.returncode}: {p.stdout!r}'
assert 'not pure' in p.stdout, f'AC-4: rejection message missing: {p.stdout!r}'
p = val('validate', '--manifest', manifest, '--skill', 'pure-skill')
assert p.returncode == 0, f'AC-4: pure skill must be allowed (exit 0), got {p.returncode}: {p.stdout!r}'
p = val('validate', '--manifest', manifest, '--skill', 'ghost')
assert p.returncode == 2, f'AC-4: unknown skill must fail loud (exit 2), got {p.returncode}'
p = val('validate', '--manifest', os.path.join(env['SCRATCH'], 'nope.toml'), '--skill', 'x')
assert p.returncode == 2, f'AC-4: unreadable manifest must fail loud (exit 2), got {p.returncode}'
# explicit --strategy sequential bypasses the purity requirement
p = val('validate', '--manifest', manifest, '--skill', 'stochastic-skill', '--strategy', 'sequential')
assert p.returncode == 0, f'AC-4: sequential must not require purity, got {p.returncode}: {p.stdout!r}'
print('OK')
" "AC-4 (unwanted): validate rejects hash for non-pure skills (STANDARD)"

report_and_exit
