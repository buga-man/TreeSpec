# log — mock scenarios

The `log` capability is cross-cutting: any stage may invoke it. These
scenarios document the two modes (run, wrap) and a few edge cases.

## Scenario 1: log a hand-built skill execution (mode=run)

**Setup:**
- `EPIC-010` is the active epic (`tree-spec.toml [epic].active`).
- The agent just executed the `brainstorm` skill mentally and has
  the output in hand (JSON: `{"draft": "REQ-LOG-001"}`).

**Expected behaviour:**
1. Step 1 — pick mode=run.
2. Step 2 — read `[epic].active` from `tree-spec.toml` (= `EPIC-010`).
3. Step 3 — write claim = "drafted REQ-LOG-001 from brainstorm";
   write verify = "draft present in output.json" (after observing).
4. Step 4 — invoke `python -m treespec_log run brainstorm --epic EPIC-010
   --input '{"topic":"logging"}' --output '{"draft":"REQ-LOG-001"}'
   --claim "..." --verify "..."`.
5. PYTHONPATH points at the skill folder (resolver inside the skill or
   caller-side).
6. Step 5 — capture the `.runs/EPIC-010/EPIC-010-NNNN/` path the CLI prints;
   reference it from the next `docs/report-NN.md`.

**Pass criterion:** the run record exists with input/output/claim/verify/
exit-code/metadata; `runs validate --path .runs` exits 0.

## Scenario 2: log an ad-hoc test invocation (mode=wrap)

**Setup:**
- The agent is about to run `bash tests/runs/test-runs.sh`.
- The agent does NOT want to hand-build a record.

**Expected behaviour:**
1. Step 1 — pick mode=wrap.
2. Step 2 — read `[epic].active`.
3. Step 3 — write claim = "ran the EPIC-010 test suite"; write verify
   = "exit 0 + 7 PASS in stdout".
4. Step 4 — invoke `bash skills/tree-spec/scripts/treespec-wrap.sh
   --epic EPIC-010 --claim "..." --verify "..." -- bash tests/runs/test-runs.sh`.
5. The wrapper captures stdout/stderr/exit-code of the wrapped test,
   writes a record, and propagates the wrapped exit code to the agent.
6. Step 5 — reference the record path.

**Pass criterion:** the run record's `output.json.exit_code` matches the
wrapped command's exit code; the wrapper's own exit code matches too
(a failing test must fail the wrapper).

## Scenario 3: command times out

**Setup:**
- Same as Scenario 2, but the wrapped command is `sleep 1000`.

**Expected behaviour:**
1. Wrapper runs the command with `--timeout 300` (default).
2. The command hits the timeout; `subprocess.run` raises `TimeoutExpired`.
3. The wrapper catches the timeout, records exit-code = 124 (conventional
   timeout exit code), and writes a stderr marker `[wrap] command timed out`.
4. The wrapper exits 124 itself.

**Pass criterion:** the record exists; `output.json.exit_code == 124`;
`exit-code.txt == "124"`; the wrapper itself exits 124.

## Scenario 4: command not found

**Setup:**
- Wrapped command is `nonexistent-binary --foo`.

**Expected behaviour:**
1. Wrapper spawns the command; `subprocess.run` raises `FileNotFoundError`.
2. The wrapper catches, records exit-code = 127 (conventional "command
   not found"), with stderr containing the FileNotFoundError text.
3. Wrapper exits 127.

**Pass criterion:** the record exists; `output.json.exit_code == 127`;
the audit trail does NOT silently drop the failed run.

## Scenario 5: self-containment check

**Setup:**
- The agent (or a CI step) wants to verify the skill is copyable.
- A scratch dir is created.

**Expected behaviour:**
1. `cp -r skills/tree-spec /tmp/skill-under-test`.
2. `cd /tmp && PYTHONPATH=/tmp/skill-under-test python -m treespec_log
   --help` — works.
3. `cd /tmp && PYTHONPATH=/tmp/skill-under-test python -m treespec_log
   run foo --epic X --claim c --verify v` — works.
4. `cd /tmp && bash /tmp/skill-under-test/scripts/treespec-wrap.sh
   --epic X --claim c --verify v -- echo hi` — works.
5. The skill folder contains EVERYTHING needed; no consumer-side setup
   beyond `PYTHONPATH`.

**Pass criterion:** all four commands exit 0; `python -m treespec_log`
resolves the package from inside the copied skill folder.