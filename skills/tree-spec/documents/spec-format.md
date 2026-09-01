# TreeSpec Format — Canonical Reference

Single source of truth for the TreeSpec spec format. The template
(`assets/spec.template.md`) and any future validation/tooling are derived
from this document. Changing a rule = edit it here first, then sync
the derivatives.

The format is **frontmatter-first**: the entire contract lives in the YAML
frontmatter; the markdown body provides context for humans and reviewers
and never overrides the frontmatter.

---

## Table of Contents

- [1. Overview](#1-overview)
- [2. File Structure and Location](#2-file-structure-and-location)
- [3. ID Allocation Rules](#3-id-allocation-rules)
- [4. EARS Patterns](#4-ears-patterns)
- [5. Status Lifecycle](#5-status-lifecycle)
- [6. Frontmatter Fields by Level](#6-frontmatter-fields-by-level)
  - [L0 · Required](#l0--required)
  - [L1 · Conditional](#l1--conditional)
  - [L2 · High/Critical Risk + Complex](#l2--highcritical-risk--complex)
- [7. Risk Levels and Conditional Requirements](#7-risk-levels-and-conditional-requirements)
- [8. Язык спеки](#8-язык-спеки)

---

## 1. Overview

A spec is a **structured contract** between requirements and their
execution (agent/developer). It declares:

- **What** the system must do → `acceptance_criteria`
- **How** success is measured → `verification` on every AC
- **The boundaries** of the work → `scope.in` / `scope.out`
- **Who** is accountable → `provenance.author`, `classification.owners`
- **Links** to epics and other specs → `epic`, `depends_on`

The format is compatible with v0.6 spec-dev-by: the same field levels
(L0/L1/L2), the same EARS patterns, the same frontmatter-first principle.
This lets us reuse the spec-dev-by validator and tools in the future
without rewriting them.

---

## 2. File Structure and Location

```
artifacts/global/biz-spec/REQ-DOMAIN-NNN.md   # one spec = one file
```

- **Encoding:** UTF-8, no BOM
- **Line endings:** LF
- **File size:** recommended ≤ ~400 lines
- **Date format:** `YYYY-MM-DD` (no time component)

One spec — one file. The file is "live": it is updated as the status
progresses and the contract changes.

---

## 3. ID Allocation Rules

Format: `REQ-<DOMAIN>-<NNN>`

- `<DOMAIN>` — **2–8 uppercase Latin letters** (e.g., `AUTH`, `API`,
  `PAY`, `EPIC`, `CMAP`, `TREESPEC`). Describes the requirement's
  area/domain. Relaxed from 2–6 to 2–8 in EPIC-005 (conflict-002)
  to accommodate the kit's self-spec `REQ-TREESPEC-001`.
- `<NNN>` — three-digit number with leading zeros; sequential within the
  domain, **never reused** after deletion.

Examples: `REQ-AUTH-042`, `REQ-PAY-001`, `REQ-CMAP-017`.

To find the next free ID, scan existing specs matching `REQ-<DOMAIN>-*`
and take `max + 1`.

> Compatibility: this format is identical to v0.6 spec-dev-by, so its
> validator (`validate.py`) will accept our IDs without changes.


---

## 4. EARS Patterns

EARS (Easy Approach to Requirements Syntax) gives every acceptance
criterion a fixed grammatical form in English, so reviewers and agents
can parse it without guessing. Pick a pattern by **trigger**, not by
importance.

| Pattern | When to use | Template (stem) | Verification method |
|---|---|---|---|
| `event_driven` | Reaction to a concrete trigger (request, timer, message) | `When <trigger>, the system shall <response>.` | `integration_test` |
| `state_driven` | Behavior while a condition holds | `While <state>, the system shall <behavior>.` | `integration_test` |
| `unwanted` | Prohibition of specific behavior | `If <condition>, then the system shall not <forbidden response>.` | `unit_test` |
| `ubiquitous` | A property that is always true | `The system shall <property>.` | `static_analysis` |
| `optional` | Nice-to-have (use "should") | `Where <context>, the system should <behavior>.` | `manual` |
| `error` | Handling/recovery from a fault | `If <error>, then the system shall <recovery>.` | `integration_test` (fault-injection) |

**Anti-patterns:**
- Mixing multiple actions in one AC — split into separate ACs.
- Hiding the trigger inside a long sentence — pull it to the front.
- Using "should" in a non-optional AC.
- Using "shall not" outside the `unwanted` pattern.
- An AC without a measurable oracle — `verification.oracle` is the contract.

---

## 5. Status Lifecycle

The spec lifecycle has **4 statuses**, tied to the stages of the
TreeSpec pipeline (see `base_idea.md`):

```
draft → approved → implemented → done
```

| Status | Meaning | When to set it |
|---|---|---|
| `draft` | Draft, questions still open | Stage 1 in progress; AI generates, human refines |
| `approved` | Approved by a human | End of stage 1: all blockers closed, [Human] approved |
| `implemented` | Code written and verified | Stages 3–4 passed: implementation + cross-check against AC |
| `done` | Accepted and synchronized | G3 closed (UAT), stage 7: biz-spec reflects behavior |

**Promotion rules:**
- Transition to `approved` requires: all L0 fields filled, no
  `open_questions[].blocking: true`, no conflicts.
- Transition to `implemented` requires: every AC implemented and
  verified against its oracle.
- The final transition to `done` is a human decision (G3).

> Compatibility with v0.6: spec-dev-by has 5 statuses (`draft`, `test`,
> `ready-to-implementation`, `implementation-in-progress`, `ready`). Our
> 4 statuses are a simplification aligned with the TreeSpec pipeline;
> if mapping to v0.6 is needed, use: draft→draft,
> approved→ready-to-implementation, implemented→implementation-in-progress,
> done→ready.

---

## 6. Frontmatter Fields by Level

All field levels are visible in the template. L0 is always required;
L1/L2 are added as needed (delete unused sections before finalizing).

### L0 · Required

Required fields for any valid spec:

| Field | Type | Constraints |
|---|---|---|
| `id` | string | `^REQ-[A-Z]{2,8}-\d{3}$` (see §3) |
| `title` | string | Non-empty, recommended ≤120 characters |
| `status` | enum | One of 4 values (see §5) |
| `type` | enum | `feature` · `bug` · `refactor` · `chore` · `spike` · `compliance` |
| `priority` | enum | `critical` · `high` · `medium` · `low` |
| `epic` | string | Link to a TreeSpec epic: `EPIC-NNN-slug` |
| `scope.in` | string[] | Non-empty; each item is a concrete deliverable |
| `scope.out` | string[] | Explicit non-goals (recommended) |
| `acceptance_criteria` | AC[] | Non-empty; each has `id`, `pattern`, `statement`, `verification` |
| `provenance.created` | date | `YYYY-MM-DD` |
| `provenance.updated` | date | `YYYY-MM-DD` (change on every commit) |
| `provenance.author` | string | Person, team, or agent |

**AC object shape:**

```yaml
- id: AC-1                 # required, unique within the spec
  pattern: event_driven    # required, enum (see §4)
  statement: |             # required, EARS-formatted English sentence
    <EARS-formatted sentence>
  verification:            # required (L2 hard requirement)
    method: integration_test
    command: "<CLI string or null>"
    environment: ci
    oracle:                # observed value == "passed"
      status_code: 200
    evidence_required: true
    evidence_format: junit_xml
```

**provenance.source_refs (optional extension):**

Links the spec back to the raw requirements it grew from
(raw → draft → spec traceability). Fill this when the spec is generated
from raw sources — intake buffer candidates or `source_doc`. Specs
without a raw source omit the field entirely (backwards compatible).

```yaml
provenance:
  source_refs:
    - path: docs/raw/auth-backlog.md   # where the raw source lives
      anchor: "BR-7"                   # heading/item id/line within it
      original_text: "Rate-limit login at 5/min/IP"
```

| Field | Type | Constraints |
|---|---|---|
| `provenance.source_refs` | object[] | Optional; ≥1 entry if present |
| `.path` | string | Path to the raw-source file (relative to repo root) |
| `.anchor` | string | Heading, item id, or line inside the file |
| `.original_text` | string | Requirement text as it appears in the source (quote) |

The `write-spec` skill validates each `path` when writing the spec:
a missing file blocks the write.

### L1 · Conditional

Fill as needed; delete irrelevant entries before finalizing:

| Field | When to add it |
|---|---|
| `revision` | Bump on any contract change; pair with `change_summary` |
| `classification.domain` | Matches the `id` prefix; for discoverability |
| `classification.stream` | UI grouping |
| `classification.owners` | Required for accountability |
| `depends_on` | Inter-spec dependencies; **no cycles** (DAG) |
| `relations` | Semantic links (extension, deprecation, etc.) |
| `risk_level` | Always set; default `medium` for new specs |
| `complexity` | Always set; default `small` |
| `constraints.invariants` | Properties that must never be violated |
| `constraints.forbidden` | Explicit blacklist of agent actions |
| `test_approach` | Required when `risk_level ≥ medium` (see §7) |
| `open_questions` | Track open questions; `blocking: true` halts promotion to `approved` |

### L2 · High/Critical Risk + Complex

Only for specs with high risk or high complexity:

| Field | When to add it |
|---|---|
| `interfaces.provides` / `consumes` | What the spec gives/needs as API contracts |
| `execution.*` | Required when `risk_level ≥ high` (see §7) |
| `failure_handling.*` | Required when `risk_level ≥ high` (see §7) |
| `fr_mapping` | Required when `complexity ∈ {medium, large, epic}` |
| `utility_threshold` | Required when `risk_level = critical` (see §7) |
| `evidence_policy` | Policy for storing run evidence |

---

## 7. Risk Levels and Conditional Requirements

The risk level determines which additional fields become mandatory:

| `risk_level` | Required additions |
|---|---|
| `low` | Nothing beyond L0 |
| `medium` | `test_approach` |
| `high` | `test_approach` + `failure_handling.rollback_plan` + `execution.approvals[]` covering every forbidden action |
| `critical` | Everything for `high` + `utility_threshold` + `failure_handling.on_data_loss: halt_and_escalate` + explicit `outputs[]` |

---

## 8. Язык спеки

Активный язык — это **директива вывода**, а не механизм разрешения файлов.
Он задаётся в `tree-spec.toml` (`[meta].language`; фаза 0 — `en` или `ru`,
любое другое значение тихо переключается на `en`) и определяет язык
человеко-читаемого прозаического текста. Машинный контракт всегда остаётся
на каноническом английском — независимо от активного языка, поэтому все
ораклы продолжают проходить.

Согласно разделу «Language of specs and artifacts (option A)» из
`specs/REQ-I18N-001.md`, разделение такое:

| Часть | Язык |
|---|---|
| Заголовок спеки (`title`), проза `scope.in` / `scope.out`, тела `Context` / `User flow` / `Notes` | активный язык |
| Артефакты — STATUS.md, PATH.md, DECISIONS.md, tasks.md, отчёты, feasibility, verification (проза) | активный язык |
| Имена полей в frontmatter | всегда канонический английский |
| Идентификаторы: REQ-*, EPIC-*, идентификаторы навыков, имена гейтов, статусы | всегда канонический английский |
| EARS `statement` и ключи паттернов | всегда канонический английский |
| `verification.command`, значения ораклов, пути к файлам | всегда канонический английский |

Этот раздел — единый источник истины, который агент применяет при написании
спеки на неанглийском языке. Идентификаторы, пути и имена полей сохраняются
без изменений.

> ⚠️ Активный язык **не создаёт** папок локализации (`documents/i18n/`) и
> не делает копии контента кита по языкам: системные файлы навыков,> справок и шаблонов остаются каноническими. Переводится только то, что> агент сам генерирует в качестве результата — спеки и артефакты.

---

## Derivative Documents

This document is the single source of truth. Derivatives (must be
synced whenever the rules change):

- `assets/spec.template.md` — skeleton for new specs (derived)
- `assets/report.template.md` — skeleton for agent reports (derived, see Concept 3 in framework-ideas.md)
- Future validator (if ported from spec-dev-by) — implements these rules

When the format changes, edit **this** document first, then sync the
derivatives. Editing only a derivative without updating this document
is the source of drift between rules and implementation.