---
# ════════════════════════════════════════════════════════════════
# SPEC TEMPLATE · TreeSpec v0.1
# Format source: spec-dev-by v0.6 (frontmatter-first)
# Canonical rule reference: documents/spec-format.md
#
# How to use:
#   1. Fill L0 completely — without it the spec is invalid.
#   2. Fill L1 and L2 only as needed; before finalization delete
#      sections that don't apply to this spec.
#   3. Replace all <PLACEHOLDER> before review.
#   4. The markdown body is only context for humans. It never
#      overrides the frontmatter.
# ════════════════════════════════════════════════════════════════

# ── L0 · REQUIRED ─────────────────────────────────────────────
id: REQ-DOMAIN-NNN              # REQ-<DOMAIN 2–6 uppercase letters>-<3 digits>, e.g. REQ-AUTH-042
title: <one line>               # imperative or description, ≤120 characters
status: draft                   # draft | approved | implemented | done
type: feature                   # feature | bug | refactor | chore | spike | compliance
priority: medium                # critical | high | medium | low

epic: EPIC-NNN-slug             # ← TreeSpec: epic reference (REQ → EPIC traceability)

scope:
  in:                           # ≥1, what is IN scope
    - "<concrete deliverable>"
  out:                          # explicit non-goals
    - "<non-goal>"

acceptance_criteria:            # ≥1 AC; each has pattern + statement + verification
  - id: AC-1
    pattern: event_driven       # EARS: event_driven | state_driven | unwanted | ubiquitous | optional | error
    statement: |
      When <trigger>, the system shall <response>.  # EARS — see spec-format.md §4
    verification:               # oracle — what counts as "passed"
      method: integration_test  # unit_test | integration_test | e2e_test | load_test | static_analysis | manual
      command: "<command or null>"
      environment: ci           # ci | staging | local | production
      oracle:                   # observed value == "passed"
        <observed_value>: true
      evidence_required: true   # true → specify evidence_format
      evidence_format: junit_xml # junit_xml | junit_json | stdout | json | markdown | screenshot | log

provenance:
  created: YYYY-MM-DD           # creation date
  updated: YYYY-MM-DD           # last-modified date (change on every commit)
  author: <who>                 # person, team, or agent
  source_refs:                  # optional — raw→spec traceability (see spec-format.md §6)
    - path: docs/raw/<source>.md   # where the raw source lives
      anchor: "<heading/item id/line>"
      original_text: "<requirement text as in the source>"

# ── L1 · CONDITIONAL (fill as needed) ─────────────────────────
revision: 1                     # bump + change_summary on any contract change

classification:
  domain: auth                  # must match the id prefix
  stream: <stream/UI grouping>
  owners: [backend-team]        # who is accountable
  tags: [security, abuse-prevention]

depends_on:                     # inter-spec dependencies (DAG, no cycles)
  - ref: REQ-AUTH-008
    reason: "Needs DB layer"
    required: true              # blocks promotion until resolved

relations:                      # semantic links, not execution
  - target: REQ-AUTH-005
    kind: extends               # extends | derives_from | alternative_to | deprecates | replaces | contradicts | supersedes_in_revision
    note: "Adds rate limiting"

risk_level: medium              # low | medium | high | critical
complexity: small               # trivial | small | medium | large | epic

constraints:
  invariants: ["<observable property that must never be violated>"]
  forbidden: ["<actions forbidden to the agent>"]
  performance:
    p95_latency_ms: 50
    error_rate_max: 0.001

test_approach:                  # REQUIRED when risk_level ≥ medium
  levels: [unit, integration]
  frameworks: [pytest]
  min_coverage_percent: 80

open_questions:                 # blocking: true → cannot be approved
  - id: Q-1
    question: "<open question>"
    blocking: false
    suggested_resolution: "<hint>"

# ── L2 · HIGH/CRITICAL RISK + COMPLEX SPECS ────────────────────
interfaces:
  provides:                     # what this spec gives the world
    - kind: endpoint
      name: POST /tokens/reset
      signature: "POST /tokens/reset { email } -> 202"
  consumes:                     # what this spec needs
    - ref: REQ-AUTH-008
      items:
        - kind: function
          name: send_email

execution:                      # REQUIRED when risk_level ≥ high
  assumptions_policy: ask_before_assuming
  plan_required: true
  permissions:
    read: [src/*/auth.py, tests/*/test_auth.py]   # ** forbidden (AP-3)
    write: [src/auth/login.py]
    network: []
    secrets: []
  forbidden_actions: [production_write_without_approval, drop_column]
  budgets:
    max_duration_minutes: 60
  stop_conditions: [missing_dependency, failing_baseline_tests]
  approvals:                    # every `before` MUST match forbidden_actions byte-for-byte
    - before: production_write_without_approval
      approver_role: backend_owner

failure_handling:               # REQUIRED when risk_level ≥ high
  rollback_required: true
  rollback_plan: |
    <step-by-step rollback>
  on_data_loss: halt_and_escalate
  escalation_owner: backend-team

fr_mapping:                     # REQUIRED when complexity ∈ {medium, large, epic}
  - fr: FR-1.1
    ac: AC-1
    note: optional

utility_threshold:              # REQUIRED when risk_level = critical
  success_at_or_above:
    pass_rate: 0.95
  reject_below:
    pass_rate: 0.80
  rationale: "Below 80% the feature is unfit for production"

evidence_policy:
  required_per_ac: true
  retention_days: 365
  store_at: .runs/REQ-XXXX-NNN/ # adjust per project

# ════════════════════════════════════════════════════════════════
# BODY (markdown) — optional, free form.
# Never overrides the frontmatter.
# ════════════════════════════════════════════════════════════════
---

## Context

<Why this spec exists. What problem, for whom, what triggered it now.>

## User flow

<Step-by-step walkthrough from the user's or system's perspective. Optional.>

## Notes

<Anything that helps the reviewer but is not part of the contract.>