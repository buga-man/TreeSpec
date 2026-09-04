# Execution Semantics (Phase 4 / CON-14)

How skills are executed and how their runs are audited. Sections land as
their epics close; this doc is the single reference for runtime behavior.

## Flaky policy & retry protocol (REQ-EXEC-004 / EPIC-012)

Deterministic tools hide flakiness; stochastic ones must surface it without
blocking progress.

### Agent retry protocol

The **agent runtime** owns execution and retries — `treespec_log` is a
passive record store and never runs skills itself:

1. Run the skill once. On first suspected failure (non-zero exit), re-run
   it up to **3 cycles by default**. A human may raise the count in chat;
   there is no upper bound enforced by the kit.
2. Record **every** attempt via `treespec_log run <skill> --epic <id>
   --exit-code <code>` (one record per attempt, append-only).
3. After the attempts are recorded, produce the epic verdict:
   `python -m treespec_log runs report <epic> [--tolerance <f>]`.

### Verdict & quarantine

- `runs report` aggregates non-chosen attempts per skill and computes
  `failed_runs / total_runs`. Chosen/consensus records link attempts and
  never count toward `total_runs`.
- When the rate exceeds the skill's `flaky_tolerance` (plugin manifest,
  default `0.0`; the agent passes it via `--tolerance`), the skill enters
  quarantine: `.runs/quarantine/<skill-id>.json` records the episode.
- A quarantined skill **does not block the epic**: the report marks it
  `flaky: known issue` and exits 0. The skill is always listed in the
  report output (audit).

### Lift rules (`treespec_log quarantine release --id <skill>`)

| Trigger | Flag | Semantics |
| --- | --- | --- |
| N consecutive clean epics | `--clean N` | default reference N = 3; the agent runtime counts clean epics and passes the count — the CLI trusts the flag (`ponytail:` per-epic verification only if a false lift ever matters) |
| Time-out | (no flags) | releases only when the entry is older than 30 days |
| Manual clear | `--manual` | unconditional |

Release deletes `<skill-id>.json` and prints
`released: <skill> (<reason>)`.

## ID strategy (REQ-EXEC-005 / EPIC-013)

Run ids come from one of two strategies; the store stays append-only in
both cases.

### Agent wiring (the CLI is manifest-agnostic)

The agent reads `[kernel].id_strategy` from `tree-spec.toml` and passes it
to the existing flag: `treespec_log run <skill> --epic <id>
--id-strategy <sequential|hash> [--input '<normalized input JSON>']`. The
CLI never parses the manifest (same pattern as flaky `--tolerance`).

### `sequential` (default)

Monotonic counter per epic: `<epic>-0001`, `<epic>-0002`, … — unique,
monotonically increasing, one new id per execution.

### `hash` (pure skills only)

Base id = `<epic>-<sha256(normalized input)[:16]>`. One logical input maps
to one **chain**:

- first run → the base id;
- a repeat run with identical input probes the next free slot of the same
  chain — `<base>-2`, `<base>-3`, … (open addressing / chaining in
  directory space). Records are never overwritten.
- every hash record carries `metadata.input_hash` (the 16-hex digest), so
  all runs of one input are queryable as a chain; `run` also prints
  `input_hash=<digest>` on stdout.

### Purity guard

`hash` is only valid for pure (deterministic) skills, declared as
`pure = true` under `[pipeline.skills.<id>]`. Before running a skill with
`--id-strategy hash`, the agent checks:

```
python -m treespec_log validate --manifest tree-spec.toml --skill <id> [--strategy hash]
```

exit 0 = allowed; exit 1 = skill not pure (do not use hash for it);
exit 2 = unknown skill / unreadable manifest (fix the typo, do not retry
blindly).
