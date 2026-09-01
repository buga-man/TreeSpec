#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tests/router/test-rules.sh — router fail-closed validation mirror
#
# This script is a **mechanical mirror** of the router's fail-closed
# validation procedure documented in:
#
#   skills/tree-spec/SKILL.md § "Validation (fail-closed)"
#
# The router validates in markdown; this test validates in shell. Both
# must pass against the current tree-spec.toml. The four check names
# are quoted verbatim from the source (per T-03 AC-6):
#
#   1. Kernel version — `[kernel].version` is compatible with this kit.
#   2. File paths — every `[pipeline.skills.*].file` path resolves
#      relative to the skill root (see "Manifest v0.2 resolution").
#   3. Entry skills — each stage's `entry_skill` is listed in that
#      stage's `skills`.
#   4. Gate skills — every gate participant of kind `skill` names a
#      declared skill.
#
# Each assert carries a stable id (ASSERT-ROUTER-NNN) so the rule
# catalog at documents/validation.md (EPIC-007) can reference the
# router procedure by id.
# ════════════════════════════════════════════════════════════════

. "$(dirname "$0")/../_lib/common.sh"

section "router — fail-closed validation (mirror of skills/tree-spec/SKILL.md § Validation)"

# ── Group 1: Kernel version ────────────────────────────────────
# Router check 1 (verbatim). Phase 0 strict: the kernel major.minor
# is fixed at 0.1; patch level may advance. Pre-release/build suffixes
# per semver are allowed.

assert_python "
import re, tomllib
v = tomllib.load(open('__PROJECT_ROOT__/tree-spec.toml', 'rb'))['kernel']['version']
assert re.match(r'^0\.1\.[0-9]+(-[A-Za-z0-9.-]+)?\$', v), \
    f'[kernel].version not 0.1.x: got {v!r}'
print('OK')
" "ASSERT-ROUTER-001: Kernel version — [kernel].version matches ^0\\.1\\.[0-9]+(-[A-Za-z0-9.-]+)?\$"

# ── Group 2: File paths ────────────────────────────────────────
# Router check 2 (verbatim). Every [pipeline.skills.*].file resolves
# relative to the skill root (skills/tree-spec/). Each must exist AND
# be a regular file (not a directory or symlink to nothing).

assert_python "
import os, tomllib
root = '__PROJECT_ROOT__'
skills_root = os.path.join(root, 'skills', 'tree-spec')
skills = tomllib.load(open(os.path.join(root, 'tree-spec.toml'), 'rb'))['pipeline']['skills']
for sid, sdata in skills.items():
    f = sdata['file']
    full = os.path.join(skills_root, f)
    assert os.path.isfile(full), f'skill {sid!r}: file not found or not a regular file at {full!r}'
print('OK')
" "ASSERT-ROUTER-002: File paths — every [pipeline.skills.*].file resolves under skills/tree-spec/"

# ── Group 3: Entry skills ──────────────────────────────────────
# Router check 3 (verbatim). Each stage's entry_skill ∈ that stage's
# `skills` list. Per the router: stages declare a `skills` array AND an
# `entry_skill` that must be a member. We also assert entry_skill ∈
# the global [pipeline.skills] (a stronger requirement that the router
# implicitly relies on).

assert_python "
import tomllib
d = tomllib.load(open('__PROJECT_ROOT__/tree-spec.toml', 'rb'))
skill_keys = set(d['pipeline']['skills'].keys())
for stage, sdata in d['pipeline']['stages'].items():
    es = sdata.get('entry_skill')
    stage_skills = sdata.get('skills', [])
    assert es is not None, f'stage {stage!r}: entry_skill missing'
    assert es in stage_skills, f'stage {stage!r}: entry_skill {es!r} not in stage.skills {stage_skills!r}'
    assert es in skill_keys, f'stage {stage!r}: entry_skill {es!r} not in [pipeline.skills] keys {sorted(skill_keys)!r}'
print('OK')
" "ASSERT-ROUTER-003: Entry skills — every stage's entry_skill ∈ stage.skills AND ∈ [pipeline.skills]"

# ── Group 4: Gate skills ───────────────────────────────────────
# Router check 4 (verbatim). Every gate participant of kind='skill'
# names a declared skill. Per the manifest v0.2 grammar, participants
# is an array of {kind, id} tables.

assert_python "
import tomllib
d = tomllib.load(open('__PROJECT_ROOT__/tree-spec.toml', 'rb'))
skill_keys = set(d['pipeline']['skills'].keys())
for gate, gdata in d['pipeline']['gates'].items():
    participants = gdata.get('participants', [])
    assert isinstance(participants, list), f'gate {gate!r}: participants must be an array'
    for p in participants:
        if not isinstance(p, dict):
            continue
        if p.get('kind') == 'skill':
            assert p.get('id') in skill_keys, (
                f'gate {gate!r}: participant skill id {p.get(\"id\")!r} not in [pipeline.skills] keys {sorted(skill_keys)!r}'
            )
print('OK')
" "ASSERT-ROUTER-004: Gate skills — every gate participant of kind=skill names a declared skill"

# ── AC-7 stdlib guard (REQ-VALID-001 AC-7) ─────────────────────
# Bonus assert: defends against future contributors adding external
# deps to this group. Excludes test-rules.sh itself (the assertions
# above mention these strings in their description / labels).

if grep -rE 'pip install|requirements\.txt' tests/router --exclude='test-rules.sh' 2>/dev/null; then
    _log_fail "ASSERT-ROUTER-005: tests/router/ contains no 'pip install' or 'requirements.txt' (REQ-VALID-001 AC-7)" \
              "remove external dependency, REQ-VALID-001 AC-7 is stdlib-only"
else
    _log_pass "ASSERT-ROUTER-005: tests/router/ contains no 'pip install' or 'requirements.txt' (REQ-VALID-001 AC-7)"
fi

report_and_exit
