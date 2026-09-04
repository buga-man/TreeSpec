---
id: log
name: log
description: write a `.runs/` record for an executed skill or ad-hoc command
version: 0.1.0
phase: 0
stage: any                              # called from any capability that wants a record
classification: pure                    # deterministic I/O, no judgement
reproducibility: strict                 # atomic temp-dir + rename makes runs reproducible
execution_mode: single                  # one execution per record
flaky_tolerance: 0.0                    # deterministic append-only store

# ── SKILL CONTRACT (CON-09) ───────────────────────────────────────
input:
  - mode: "run" | "wrap"                # run = record only; wrap = record + execute
  - epic_id: string                     # EPIC-NNN-slug
  - claim: string                       # what the run is intended to do
  - verify: string                      # what to observe after the run
  - skill: string | null                # for mode=run: the skill slug
  - command: string[] | null            # for mode=wrap: the argv to execute
output:
  - record_path: path                   # .runs/<epic>/<run-id>/ (always)
side_effects:
  - writes a record under .runs/<epic>/<run-id>/
  - for mode=wrap: spawns the command and captures stdout/stderr/exit-code
  - never overwrites an existing record (append-only)
failure_com:
  - on_partial_write: "atomic temp-dir + rename guarantees no half-written record"
  - on_command_not_found: "record exit-code=127, do not abort logging"
  - on_command_timeout: "record exit-code=124, do not abort logging"
composition:
  - may_invoke: []                      # terminal capability; no nesting
# Language (REQ-I18N-001): this skill's human-readable artifact prose
# follows the active language; identifiers, paths, oracles stay English.
---

# Skill: log

**Stage:** any — invoked by any other capability that wants an
audit-trail record of its work.
**Purpose:** turn one execution (a skill run or an ad-hoc command)
into an append-only `.runs/<epic>/<run-id>/` record.

> **Source of truth:** `tree-spec.toml` section
> `[pipeline.evaluation] claim_verify` (every report has claim + verify)
> and the runtime contract in
> `skills/tree-spec/treespec_log/runs.py` (atomic write, sequential id).
> If they ever disagree, the manifest wins — escalate to the human.

This capability is the **procedural face** of the runtime that lives at
`skills/tree-spec/treespec_log/`. The runtime handles record I/O; this
skill tells the agent **when** and **how** to call it.

---

## Procedure

### Step 1. Pick the mode

Two entry points — both land in `.runs/`:

> **Execution modes (`single` / `best-of-n` / `consensus`) are a `run`-only
> surface (REQ-EXEC-003 / EPIC-011).** Use `--mode` on `python -m treespec_log
> run` to record the mode of an attempt; `--chosen --attempts <ids>` records
> the chosen/consensus record that links to its attempts. `wrap` never sets a
> mode — it stays `single`. The actual skill execution / seed assignment /
> output selection is done by the calling runtime and is logged through `run`.

Two entry points — both land in `.runs/`:

| Mode | When to use | Entry |
|------|-------------|-------|
| `run` | The agent has already produced the skill's output and just needs to write a record of it. | `python -m treespec_log run <skill> --epic <id> --claim ... --verify ... --input ... --output ...` |
| `wrap` | The agent wants to log an arbitrary shell command (test, build, lint) without doing the work itself. | `bash skills/tree-spec/scripts/treespec-wrap.sh --epic <id> --claim ... --verify ... -- <cmd>` |

Prefer `wrap` for anything that already runs as a shell command — it
captures stdout/stderr/exit-code automatically and propagates the
exit code to the caller. Use `run` only when the skill produces
structured output the agent already has in hand.

### Step 2. Pick the epic

Read `[epic].active` from `tree-spec.toml` (or follow the human's
explicit instruction). Pass `--epic <id>` to the runtime. The runtime
writes to `.runs/<id>/`.

### Step 3. Compose claim and verify

- **claim** — what this run is intended to do. Write it **before**
  executing (intent), not after.
- **verify** — what to observe after the run. For `wrap`, write it
  before; for `run`, write it after observing the skill's output.

Both land in `claim.md` and `verify.md` of the record. They satisfy
`[pipeline.evaluation] claim_verify` (kernel invariant 3) — every
report must have both.

### Step 4. Execute + write

#### Mode `run`

```bash
cd <consumer-repo-root>
python -m treespec_log run <skill-slug> \
    --epic "$ACTIVE_EPIC" \
    --input '{"q":"..."}' \
    --output '{"result":"..."}' \
    --claim "what I did" \
    --verify "what I observed"
```

`PYTHONPATH` must point at the skill folder so `python -m treespec_log`
resolves. The skill folder IS the source of truth for the runtime —
copy `skills/tree-spec/` to a new consumer repo and the runtime comes
with it.

#### Mode `wrap`

```bash
bash <skill-root>/scripts/treespec-wrap.sh \
    --epic "$ACTIVE_EPIC" \
    --claim "what I'm running" \
    --verify "what to observe" \
    -- <cmd> [args...]
```

The wrapper resolves its own `PYTHONPATH` from `BASH_SOURCE[0]` — no
external setup required. The wrapper propagates the wrapped command's
exit code to the caller, so a CI step that wraps a failing test fails
itself; the record still captures the failure (audit trail never
drops incidents).

### Step 5. Reference the record

In your report (`docs/report-NN.md`), link the record path the runtime
prints:

```
.runs/<epic>/<run-id>/
```

so the next reader can find the input, output, claim, verify,
exit-code, and metadata without re-running anything.

---

## Anti-patterns

- ❌ Using `--mode` / `--chosen` with the `wrap` capability — modes are a
  `run`-only surface; `wrap` always records `mode = single`.
- ❌ Calling `python -m treespec_log run` from outside the skill folder
  without setting `PYTHONPATH` — the module won't resolve.
- ❌ Calling the `wrap` capability with a literal `--` in the wrapped
  command's argv — `--` ends the wrap args, so anything after is
  passed to treespec_log, not the wrapped command.
- ❌ Writing claim/verify retrospectively **and** claiming the run was
  idempotent — claim is intent (before), verify is observation
  (after). Conflating them defeats the audit.
- ❌ Skipping the log step because "it's just a small command" — every
  execution that touches state should be recordable, even small ones.
- ❌ Pretending the record can be edited — `.runs/` is append-only by
  design. If you need to correct something, write a new record; the
  history is the source of truth.

---

## Claim / Verify

- **Claim:** "An execution produced an append-only `.runs/<epic>/<run-id>/`
  record with input/output/claim/verify/exit-code/metadata, and the
  agent referenced the record path in its report."
- **Verify (run by the `verify` skill at stage 4):**
  - `tests/runs/test-runs.sh` covers the runtime contract
    (AC-1..4 for `run`, AC-5..7 for `wrap`).
  - `tests/run-all.sh` includes the `runs` group.
  - A clean store passes `python -m treespec_log runs validate --path .runs`
    (exit 0); an incomplete record fails (exit 1).
  - Every `docs/report-NN.md` of an epic that used `log` references
    a concrete `.runs/<epic>/<run-id>/` path.
