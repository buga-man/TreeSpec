# `artifacts/` — directory layout reference

> **Source of truth** for the on-disk shape of the `artifacts/` folder.
> Skills (`write-spec`, `plan`) read this document to know what to create
> during bootstrap; specs and tests assert against it. No template files
> are required — the structure is fully described here.

## Top-level tree

```
artifacts/
├── README.md                  # agent protocol (session start/end)
├── INDEX.md                   # live epic index (one row per epic)
├── global/
│   ├── biz-spec/              # cross-cutting REQs (REQ-DOMAIN-NNN.md)
│   │   └── README.md          # domain / numbering conventions
│   └── intake/                # EPIC-002+ — raw-requirements buffer
│       └── REQUIREMENTS.md    # append-only candidate table
└── epics/
    └── EPIC-NNN-<slug>/       # one folder per epic
        ├── STATUS.md          # current state (stage, status, done checklist)
        ├── PATH.md            # append-only transition history
        ├── DECISIONS.md       # append-only decision log
        ├── tasks.md           # task table with statuses + per-task detail
        └── docs/              # stage artifacts
            ├── biz-spec-delta.md
            ├── feasibility.md
            ├── verification.md
            ├── report-NN.md   # one per task in stage 3
            └── conflict-NN.md # only if a conflict was opened
```

## File roles

| Path | Purpose | Created by |
|---|---|---|
| `artifacts/README.md` | Agent protocol: session start/end rules | `write-spec` Step 0 (bootstrap) |
| `artifacts/INDEX.md` | Live table of epics and their stages | `write-spec` Step 5 (register) |
| `artifacts/global/biz-spec/README.md` | Domain / numbering conventions | `write-spec` Step 0 (bootstrap) |
| `artifacts/global/biz-spec/REQ-DOMAIN-NNN.md` | Approved specs | `write-spec` Step 3 |
| `artifacts/global/intake/REQUIREMENTS.md` | Raw-requirements candidate buffer | `intake` Step 0 (bootstrap) |
| `artifacts/epics/EPIC-NNN-<slug>/STATUS.md` | Epic state pointer | `plan` Step 1 |
| `artifacts/epics/EPIC-NNN-<slug>/PATH.md` | Append-only stage transitions | every stage transition |
| `artifacts/epics/EPIC-NNN-<slug>/DECISIONS.md` | Append-only decisions | every gate decision |
| `artifacts/epics/EPIC-NNN-<slug>/tasks.md` | Task table + per-task detail | `plan` Step 3 |
| `artifacts/epics/EPIC-NNN-<slug>/docs/biz-spec-delta.md` | REQs introduced/modified | `write-spec` Step 4 |
| `artifacts/epics/EPIC-NNN-<slug>/docs/feasibility.md` | Plan-stage risks + recommendation | `plan` Step 2 |
| `artifacts/epics/EPIC-NNN-<slug>/docs/verification.md` | Verification evidence (AC oracles) | `verify` Step 5 |
| `artifacts/epics/EPIC-NNN-<slug>/docs/report-NN.md` | Per-task implementation report | `implement` |
| `artifacts/epics/EPIC-NNN-<slug>/docs/conflict-NN.md` | Conflict record | `write-spec` Step 6 |

## Bootstrap invariants

When the kit is first installed on a fresh project, the following must
exist after bootstrap (asserted by `REQ-TREESPEC-001` AC-6):

- `artifacts/README.md` — file
- `artifacts/INDEX.md` — file
- `artifacts/global/biz-spec/` — directory
- `artifacts/global/biz-spec/README.md` — file (optional but recommended)
- `artifacts/epics/` — directory

Note: `artifacts/global/intake/`, `artifacts/epics/_TEMPLATE_EPIC/` and
similar subdirectories are **created on demand** by the skill that owns
them (`intake`, `plan`), not at bootstrap. The bootstrap minimum is the
5 entries above.

## Naming conventions

- Epic folder: `EPIC-NNN-<slug>` (zero-padded number, lowercase kebab-case slug).
- Spec id: `REQ-<DOMAIN>-<NNN>` (2–6 uppercase letters per `documents/spec-format.md`).
- Conflict doc: `conflict-NNN.md` (sequential inside the epic).
- Report: `report-NN.md` (per task in stage 3, sequential).
- Decisions / PATH: append-only; never rewrite history; corrections are new entries referencing the old.

## Why no template files

Earlier versions of the kit carried an `artifacts/epics/_TEMPLATE_EPIC/`
folder with 5 template files that new epics would copy. This required a
separate bootstrap step (and silently failed when the templates were not
shipped). The current design replaces those files with this reference
document: skills know the layout, create the bare minimum on demand, and
the structure is asserted against the invariants above rather than
against a copied template directory.
