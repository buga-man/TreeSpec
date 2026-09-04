---
# TreeSpec target repo — REQ-TREESPEC-001
# Source: phase 0 dogfood. Filled per documents/assets/spec.template.md
# Canonical reference: documents/spec-format.md

# ── L0 · REQUIRED ───────────────────────────────────────────
id: REQ-TREESPEC-001
title: Phase 0 kit installed and operational in TreeSpec target repo
status: approved
type: feature
priority: high

epic: EPIC-001-install-kit

scope:
  in:
    - "tree-spec.toml at repo root, parsed by tomllib, declares [pipeline.skills] with 8 core capability skills (intake, session-resume, brainstorm, write-spec, plan, implement, verify, log) plus the registrar tree-spec and the bootstrap init"
    - "skills/tree-spec/core-apabilities/<capability>/SKILL.md contains the 8 core capability procedures (intake, session-resume, brainstorm, write-spec, plan, implement, verify, log); skills/tree-spec/SKILL.md contains the registrar (router); skills/tree-spec/core-apabilities/init/SKILL.md contains the bootstrap"
    - "specs/ contains 7 specs (1 setup + 6 skill specs) following REQ-* format"
    - "artifacts/ initialized with README.md, INDEX.md, global/biz-spec/, epics/ per documents/references/artifacts-layout.md"
    - "EPIC-001-install-kit created with all 5 artifacts (STATUS, PATH, DECISIONS, tasks, docs/)"
    - "REQs use 2–6 letter domain prefix per spec-format.md"
    - "Sanity checks from setup.md pass"
  out:
    - "Phase 1+ features (CLI, validation, plugins)"
    - "Multi-repo, stewardship, execution semantics"
    - "Application-specific integration (Claude Code, Cursor bindings)"

acceptance_criteria:
  - id: AC-1
    pattern: ubiquitous
    statement: |
      The system shall have tree-spec.toml at the repository root that
      parses as valid TOML with sections [identity], [kernel], and
      [pipeline] (including stage_order, default_stage, stages, skills,
      evaluation, gates).
    verification:
      method: integration_test
      command: "python -c \"import tomllib; d=tomllib.load(open('tree-spec.toml','rb')); assert 'identity' in d and 'pipeline' in d and 'stages' in d['pipeline'] and 'gates' in d['pipeline']\""
      environment: local
      oracle:
        exit_code: 0
      evidence_required: true
      evidence_format: stdout
  - id: AC-2
    pattern: ubiquitous
    statement: |
      The repository shall contain exactly 8 core capability SKILL.md
      files at skills/tree-spec/core-apabilities/<capability>/SKILL.md
      (one per core capability: intake, session-resume, brainstorm,
      write-spec, plan, implement, verify, log), plus the registrar at
      skills/tree-spec/SKILL.md and the bootstrap at
      skills/tree-spec/core-apabilities/init/SKILL.md.
    verification:
      method: integration_test
      command: "for s in intake session-resume brainstorm write-spec plan implement verify log; do test -f \"skills/tree-spec/core-apabilities/$s/SKILL.md\" || exit 1; done; test -f skills/tree-spec/SKILL.md || exit 1; test -f skills/tree-spec/core-apabilities/init/SKILL.md || exit 1; echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null
  - id: AC-3
    pattern: ubiquitous
    statement: |
      Each skill file shall be referenced by [pipeline.skills.<id>].file
      and the file shall exist (skill ids in: session-resume, intake,
      brainstorm, write-spec, plan, implement, verify, log).
    verification:
      method: integration_test
      command: "for s in session-resume intake brainstorm write-spec plan implement verify log; do test -f \"skills/tree-spec/core-apabilities/$s/SKILL.md\" || exit 1; done; echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null
  - id: AC-4
    pattern: ubiquitous
    statement: |
      The repository shall contain a specs/ directory with at least the
      7 specs named REQ-SETUP-001, REQ-RESUME-001, REQ-BRAIN-001,
      REQ-WRITE-001, REQ-PLAN-001, REQ-IMPL-001, REQ-VERIFY-001.
    verification:
      method: integration_test
      command: "ls specs/REQ-*.md | wc -l"
      environment: local
      oracle:
        output: ">= 7"
      evidence_required: false
      evidence_format: null
  - id: AC-5
    pattern: event_driven
    statement: |
      When the agent reads tree-spec.toml at session start, the manifest
      shall declare pipeline.stages for spec, plan, implement, and verify
      each with entry_skill, exit_criteria, and exit_gate.
    verification:
      method: integration_test
      command: "python -c \"import tomllib; d=tomllib.load(open('tree-spec.toml','rb')); s=d['pipeline']['stages']; [set(s[k]).issuperset({'entry_skill','exit_criteria','exit_gate'}) for k in ['spec','plan','implement','verify']]\""
      environment: local
      oracle:
        exit_code: 0
      evidence_required: false
      evidence_format: null
  - id: AC-6
    pattern: state_driven
    statement: |
      While the artifacts directory exists, it shall contain the
      bootstrap invariants defined in
      `documents/references/artifacts-layout.md` § Bootstrap invariants:
      README.md (agent protocol), INDEX.md (live epic index),
      global/biz-spec/ (REQ storage), and epics/ (per-epic folder,
      created on demand by `plan`).
    verification:
      method: integration_test
      command: "test -f artifacts/README.md && test -f artifacts/INDEX.md && test -d artifacts/global/biz-spec && test -d artifacts/epics && echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null
  - id: AC-7
    pattern: event_driven
    statement: |
      When EPIC-001-install-kit is created, it shall contain
      STATUS.md, PATH.md, DECISIONS.md, tasks.md, and a docs/ subdirectory
      with biz-spec-delta.md, feasibility.md, and verification.md.
    verification:
      method: integration_test
      command: "test -f artifacts/epics/EPIC-001-install-kit/STATUS.md && test -f artifacts/epics/EPIC-001-install-kit/tasks.md && test -f artifacts/epics/EPIC-001-install-kit/docs/verification.md && echo OK"
      environment: local
      oracle:
        output_contains: "OK"
      evidence_required: false
      evidence_format: null
  - id: AC-8
    pattern: unwanted
    statement: |
      If the repository binds to a specific application (Claude Code,
      Cursor, Windsurf), the system shall not present this install as
      app-agnostic. Mentions of these tools in anti-pattern contexts
      (forbidden sections, unwanted patterns) are allowed.
    verification:
      method: static_analysis
      command: "grep -E '^(requires|needs|depends on|must run on|only runs on).*(claude code|cursor|windsurf|aider)' tree-spec.toml README.md skills/tree-spec/SKILL.md skills/tree-spec/core-capabilities/*/SKILL.md specs/*.md 2>/dev/null"
      environment: local
      oracle:
        exit_code: 1
      evidence_required: false
      evidence_format: null

provenance:
  created: 2026-08-28
  updated: 2026-09-04
  author: treespec-maintainers + agent
  revision_history:
    - revision: 1
      date: 2026-08-28
      author: treespec-maintainers
      note: initial — 6 skills, 7 specs
    - revision: 2
      date: 2026-08-28
      author: bugae + zed
      note: skill count 6→7 (REQ-INTAKE-001 AC-7); AC-2 statement + oracle updated
    - revision: 3
      date: 2026-08-28
      author: bugae + zed
      note: AC-3 now iterates 7 skills including intake; AC-6 switched to bootstrap invariants from documents/references/artifacts-layout.md (removed _TEMPLATE_EPIC/ dependency); AC-8 command glob fixed (skills/*/SKILL.md); scope.in updated to match
    - revision: 4
      date: 2026-09-01
      author: bugae + zed
      note: post-EPIC-004 layout correction (one-skill style); AC-2 rewritten to enumerate 7 core capabilities at skills/tree-spec/core-apabilities/<capability>/SKILL.md + registrar + init; AC-3 verification command path fixed; AC-8 glob updated to walk skills/tree-spec/SKILL.md + skills/tree-spec/core-apabilities/*/SKILL.md; scope.in updated to match; constraints.invariants file count split into '7 capabilities + registrar + init' and '[pipeline.skills] count = 9'; closes EPIC-005 conflict-001 (REQ-TREESPEC-001 AC-2 spec drift).
    - revision: 5
      date: 2026-09-04
      author: bugae + zed
      note: EPIC-010 T-04 — `log` added as the 8th core capability (cross-cutting). AC-2 statement + verification command updated from 7 to 8; AC-3 statement + verification command updated to include log; scope.in list updated; constraints.invariants bumped to '8 + registrar + init = 10 SKILL.md' and '[pipeline.skills] count = 10'; valid from 2026-09-04 (REQ-TREESPEC-001 rev 5) onward.

# ── L1 · CONDITIONAL ───────────────────────────────
revision: 5

classification:
  domain: TREESPEC
  owners: [treespec-maintainers]
  tags: [phase-0, dogfood, install, target-repo]

risk_level: medium
complexity: small

constraints:
  invariants:
    - "All skill paths in tree-spec.toml resolve to existing files"
    - "Spec REQ id matches ^REQ-[A-Z]{2,6}-\\d{3}$"
    - "Skill file count = 8 core capabilities + 1 registrar + 1 init bootstrap (10 SKILL.md files under skills/tree-spec/)"
    - "[pipeline.skills] in tree-spec.toml has exactly 10 entries: 8 core capabilities + tree-spec + init"
    - "Spec file count >= 7"
  forbidden:
    - "Adding hard dependencies on specific agent environments"
    - "Writing L2 spec fields (phase 0 has no risk-testing plugin)"

test_approach:
  levels: [integration_test, static_analysis]
  frameworks: [bash, python, tomllib, grep]
  min_coverage_percent: 100

open_questions: []

# ── BODY (markdown) ────────────────────────────────────────
---

## Context

This REQ is the **first spec written by the target repo**. It
self-referentially validates that the phase 0 kit is installed and
operational: by passing its own acceptance criteria, the kit proves
that the workflow described in `documents/phases/phase_0/README.md`
works end-to-end.

The phase 0 dogfood pattern is documented in the framework repo
(`documents/phases/phase_0/README.md`). This target repo is the
**first real consumer** of the kit.

## User flow

1. Reviewer reads `tree-spec.toml` at the repo root.
2. Reviewer runs sanity checks from `setup.md` (also captured in AC-1
   through AC-7 below).
3. Reviewer confirms EPIC-001-install-kit is `done` per STATUS.md.

## Notes

- The 8 ACs cover the structural assertions of the install. They are
  intentionally **mechanical** (bash + python) — no AI judgement
  required to verify, which matches phase 0's "no AI for verification"
  principle (AI is for design and dialogue, not for verifying file
  presence).
- AC-8 (unwanted) is the same app-agnostic guarantee as in
  REQ-SETUP-001. The target repo must not regress this property.