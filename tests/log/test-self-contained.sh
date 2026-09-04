#!/usr/bin/env bash
# Tests for the log capability — self-containment.
#
# The `tree-spec` skill must be copyable as a unit: copy
#  skills/tree-spec/ to a scratch dir, point PYTHONPATH at it, and the
#  runtime (python -m treespec_log, treespec-wrap.sh) works without
#  any consumer-side setup. This test is the proof.
#
# Lives next to the log tests because the runtime behind `log` is what
# has to be self-contained — the bash entry points and Python package
#  live inside skills/tree-spec/.

. "$(dirname "$0")/../_lib/common.sh"

section "log — self-containment (copy skill, run from scratch)"

# All env vars consumed by the assert_python expressions below — set
# them once in bash (assert_python doesn't pass arbitrary env).
export SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)/skills/tree-spec"
export SCRATCH="$(mktemp -d)"
export WRAPPER="$SCRATCH/copied-skill/scripts/treespec-wrap.sh"
export BASH_BIN="$(command -v bash)"
trap 'rm -rf "$SCRATCH"' EXIT

# 1. Copy the skill folder into a scratch dir (no consumer setup).
assert_python "
import os, shutil
src = os.environ['SKILL_DIR']
dst = os.path.join(os.environ['SCRATCH'], 'copied-skill')
shutil.copytree(src, dst)
for rel in (
    'SKILL.md',
    'core-capabilities/log/SKILL.md',
    'scripts/treespec-wrap.sh',
    'scripts/tree-spec-check.sh',
    'treespec_log/__init__.py',
    'treespec_log/__main__.py',
    'treespec_log/runs.py',
    'treespec_log/wrap.py',
):
    assert os.path.isfile(os.path.join(dst, rel)), f'missing {rel} after copy'
print('OK')
" "skill copies as a unit (8 key paths present)"

# 2. python -m treespec_log resolves from the copied skill.
# PYTHONPATH points at the skill root; no consumer config required.
assert_python "
import os, subprocess, sys
env = dict(os.environ)
env['PYTHONPATH'] = os.path.join(os.environ['SCRATCH'], 'copied-skill')
r = subprocess.run(
    [sys.executable, '-m', 'treespec_log', '--help'],
    cwd=os.environ['SCRATCH'], env=env,
    capture_output=True, text=True,
)
assert r.returncode == 0, (r.stdout, r.stderr)
assert 'treespec_log' in r.stdout, r.stdout
print('OK')
" "python -m treespec_log resolves from copied skill (PYTHONPATH=copied-skill)"

# 3. python -m treespec_log run writes a record from the copied skill.
assert_python "
import os, subprocess, sys
env = dict(os.environ)
env['PYTHONPATH'] = os.path.join(os.environ['SCRATCH'], 'copied-skill')
work = os.path.join(os.environ['SCRATCH'], 'work')
os.makedirs(work, exist_ok=True)
r = subprocess.run(
    [sys.executable, '-m', 'treespec_log', 'run', 'brainstorm',
     '--epic', 'EPIC-SELF', '--input', '{}',
     '--claim', 'self-contained smoke', '--verify', 'record created'],
    cwd=work, env=env, capture_output=True, text=True,
)
assert r.returncode == 0, (r.stdout, r.stderr)
rec_root = os.path.join(work, '.runs', 'EPIC-SELF')
runs = sorted(os.listdir(rec_root))
assert runs, 'no record written'
rec = os.path.join(rec_root, runs[-1])
for key in ('input.json', 'output.json', 'claim.md', 'verify.md',
            'exit-code.txt', 'metadata.json'):
    assert os.path.isfile(os.path.join(rec, key)), f'missing {key} in {rec}'
print('OK')
" "treespec_log run works from copied skill (full record layout)"

# 4. treespec-wrap.sh works from the copied skill via absolute path.
# BASH_SOURCE[0] must point at the script even when invoked as
# `bash /abs/path/treespec-wrap.sh`, which is how the agent / CI
# would invoke it after a copy.
assert_python "
import os, subprocess, sys
env = dict(os.environ)
env['PYTHONPATH'] = os.path.join(os.environ['SCRATCH'], 'copied-skill')
work = os.path.join(os.environ['SCRATCH'], 'work2')
os.makedirs(work, exist_ok=True)
r = subprocess.run(
    [env['BASH_BIN'], os.environ['WRAPPER'],
     '--epic', 'EPIC-WRAP',
     '--claim', 'self-contained wrap', '--verify', 'echoed hello',
     '--', 'echo', 'hello-from-copied'],
    cwd=work, env=env, capture_output=True, text=True,
)
assert r.returncode == 0, (r.stdout, r.stderr)
assert 'command-exit: 0' in r.stdout, r.stdout
rec_root = os.path.join(work, '.runs', 'EPIC-WRAP')
assert os.path.isdir(rec_root), f'no record dir at {rec_root}'
print('OK')
" "treespec-wrap.sh works from copied skill (BASH_SOURCE resolves)"

# 5. treespec-wrap.sh propagates exit code from the wrapped command
#    (CI smoke: a failing test must fail the wrapper, not silently pass).
assert_python "
import json, os, subprocess, sys
env = dict(os.environ)
env['PYTHONPATH'] = os.path.join(os.environ['SCRATCH'], 'copied-skill')
work = os.path.join(os.environ['SCRATCH'], 'work3')
os.makedirs(work, exist_ok=True)
r = subprocess.run(
    [env['BASH_BIN'], os.environ['WRAPPER'],
     '--epic', 'EPIC-FAIL',
     '--claim', 'expect failure', '--verify', 'exit nonzero',
     '--', 'python', '-c', 'import sys; sys.exit(5)'],
    cwd=work, env=env, capture_output=True, text=True,
)
assert r.returncode == 5, f'wrapper must propagate exit code, got {r.returncode}'
rec_root = os.path.join(work, '.runs', 'EPIC-FAIL')
runs = sorted(os.listdir(rec_root))
assert runs, 'failure record not written'
outp_path = os.path.join(rec_root, runs[-1], 'output.json')
outp = json.load(open(outp_path))
assert outp['exit_code'] == 5, outp
print('OK')
" "treespec-wrap.sh propagates exit code AND records the failure"

report_and_exit