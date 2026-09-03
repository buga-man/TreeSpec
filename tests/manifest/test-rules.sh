#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tests/manifest/test-rules.sh — manifest rule assertions (schema-aware)
#
# Source of truth: documents/concepts/10-manifest.md (CON-10) +
# tree-spec.toml [pipeline.skills.tree-spec] validation procedure
# (skills/tree-spec/SKILL.md § "Validation (fail-closed)").
#
# Each assert has a stable id (ASSERT-MANIFEST-NNN) so the rule
# catalog at documents/validation.md (EPIC-007) can reference it.
#
# Coverage map (16 asserts):
#   001..007  7 required sections
#   008       [kernel].version matches semver (phase 0 strict)
#   009       [identity].name matches kebab-case
#   010       [pipeline.skills.*].file resolves under skills/tree-spec/
#   011       [pipeline.stages.*].entry_skill ∈ [pipeline.skills]
#   012       [pipeline.gates.*].participants[kind=skill].id ∈ [pipeline.skills]
#   013       [epic] key present (machine-maintained but required)
#   014       [meta].language ∈ {en, ru}
#   015       [pipeline.evaluation] present (extra user-owned section)
#   016       tests/manifest/ is stdlib-only (REQ-VALID-001 AC-7)
#
# Schema awareness (REQ-VALID-002 / EPIC-006): this suite runs against
# any manifest chosen by $TESTS_MANIFEST (default: tree-spec.toml at the
# project root). A v0.2 manifest declares [pipeline.skills.tree-spec];
# older (pre-v0.2) manifests do not. The four v0.2-era asserts
# (003, 010, 013, 014) are reported as an explicit SKIP with reason on
# pre-v0.2 manifests instead of failing — the deferral mandated by
# DoD-3 phase 1. Skips never affect the exit code.
#
# The python asserts read the manifest path from the exported env
# (TESTS_PROJECT_ROOT + TESTS_MANIFEST); schema and the per-assert skip
# flag are propagated to common.sh via the exported SKIP_SCHEMA and a
# trailing "v0.1" positional argument on the four v0.2-only asserts.
# ════════════════════════════════════════════════════════════════

. "$(dirname "$0")/../_lib/common.sh"

# Detect this manifest's schema before any assertion runs. Schema
# detection is structural and non-circular: a v0.2 manifest declares the
# router skill table; a pre-v0.2 manifest never does.
if grep -q '^\[pipeline\.skills\.tree-spec\]' "$TESTS_PROJECT_ROOT/$TESTS_MANIFEST" 2>/dev/null; then
    MANIFEST_SCHEMA="v0.2"
else
    MANIFEST_SCHEMA="v0.1"
fi
export SKIP_SCHEMA="$MANIFEST_SCHEMA"

# Absolute path to the chosen manifest, injected into the python asserts.
MANIFEST_PATH="$TESTS_PROJECT_ROOT/$TESTS_MANIFEST"

# ── Group 1: 7 required sections ──────────────────────────────
# Each assert confirms the TOML table path exists. tomllib walks
# `d['pipeline']['stages']` etc.; missing parents raise KeyError, the
# helper captures the error and counts it as a failure.

assert_toml_field "$TESTS_MANIFEST" "identity"         "ASSERT-MANIFEST-001: [identity] present"
assert_toml_field "$TESTS_MANIFEST" "kernel"           "ASSERT-MANIFEST-002: [kernel] present"
assert_toml_field "$TESTS_MANIFEST" "meta"         "ASSERT-MANIFEST-003: [meta] present"        "" "v0.1"
assert_toml_field "$TESTS_MANIFEST" "pipeline"         "ASSERT-MANIFEST-004: [pipeline] present"
assert_toml_field "$TESTS_MANIFEST" "pipeline.stages"  "ASSERT-MANIFEST-005: [pipeline.stages] present"
assert_toml_field "$TESTS_MANIFEST" "pipeline.skills"  "ASSERT-MANIFEST-006: [pipeline.skills] present"
assert_toml_field "$TESTS_MANIFEST" "pipeline.gates"   "ASSERT-MANIFEST-007: [pipeline.gates] present"

# ── Group 2: kernel.version semver (phase 0 strict) ───────────

assert_python "
import re, tomllib, os
mf = os.path.join(os.environ['TESTS_PROJECT_ROOT'], os.environ['TESTS_MANIFEST'])
v = tomllib.load(open(mf, 'rb'))['kernel']['version']
assert re.fullmatch(r'0\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?', v), f'kernel.version not semver: {v!r}'
print('OK')
" "ASSERT-MANIFEST-008: [kernel].version matches semver (0.x.y format)"

# ── Group 3: identity.name kebab-case ─────────────────────────

assert_python "
import re, tomllib, os
mf = os.path.join(os.environ['TESTS_PROJECT_ROOT'], os.environ['TESTS_MANIFEST'])
n = tomllib.load(open(mf, 'rb'))['identity']['name']
assert re.fullmatch(r'[a-z][a-z0-9-]*', n), f'identity.name not kebab-case: {n!r}'
print('OK')
" "ASSERT-MANIFEST-009: [identity].name matches kebab-case (lowercase + hyphens)"

# ── Group 4: [pipeline.skills.*].file resolves to a real file ─
# Per [pipeline.stages.spec] exit_criteria + the router validation
# step 2 (file paths). Each `[pipeline.skills.<id>].file` is relative
# to skills/tree-spec/ (the skill root for the v0.2 packaged layout).

assert_python "
import os, tomllib
root = os.environ['TESTS_PROJECT_ROOT']
mf = os.path.join(root, os.environ['TESTS_MANIFEST'])
skills_root = os.path.join(root, 'skills', 'tree-spec')
skills = tomllib.load(open(mf, 'rb'))['pipeline']['skills']
for sid, sdata in skills.items():
    f = sdata['file']
    full = os.path.join(skills_root, f)
    assert os.path.isfile(full), f'skill {sid}: file not found at {full!r}'
print('OK')
" "ASSERT-MANIFEST-010: every [pipeline.skills.*].file resolves under skills/tree-spec/" "" "v0.1"

# ── Group 5: [pipeline.stages.*].entry_skill in [pipeline.skills] ─

assert_python "
import os, tomllib
root = os.environ['TESTS_PROJECT_ROOT']
mf = os.path.join(root, os.environ['TESTS_MANIFEST'])
d = tomllib.load(open(mf, 'rb'))
skill_keys = set(d['pipeline']['skills'].keys())
for stage, sdata in d['pipeline']['stages'].items():
    es = sdata.get('entry_skill')
    assert es is not None, f'stage {stage!r}: entry_skill missing'
    assert es in skill_keys, f'stage {stage!r}: entry_skill {es!r} not in [pipeline.skills] keys'
print('OK')
" "ASSERT-MANIFEST-011: every [pipeline.stages.*].entry_skill in [pipeline.skills]"

# ── Group 6: gates.participants[kind=skill].id in [pipeline.skills] ─

assert_python "
import os, tomllib
root = os.environ['TESTS_PROJECT_ROOT']
mf = os.path.join(root, os.environ['TESTS_MANIFEST'])
d = tomllib.load(open(mf, 'rb'))
skill_keys = set(d['pipeline']['skills'].keys())
for gate, gdata in d['pipeline']['gates'].items():
    participants = gdata.get('participants', [])
    assert isinstance(participants, list), f'gate {gate!r}: participants must be an array'
    for p in participants:
        if not isinstance(p, dict):
            continue  # tomllib may return list of dicts; tolerate entries
        if p.get('kind') == 'skill':
            assert p.get('id') in skill_keys, (
                'gate ' + repr(gate) + ': participant skill id ' + repr(p.get('id')) + ' not in [pipeline.skills] keys'
            )
print('OK')
" "ASSERT-MANIFEST-012: every gate participant of kind=skill has id in [pipeline.skills]"

# ── Group 7: [epic] key present ───────────────────────────────
# Machine-maintained pointer (recomputed from artifacts/INDEX.md at
# router start); the key itself must exist.

assert_toml_field "$TESTS_MANIFEST" "epic" "ASSERT-MANIFEST-013: [epic] key present (machine-maintained pointer)" "" "v0.1"

# ── Group 8: [meta].language whitelist ────────────────────────

assert_python "
import os, tomllib
mf = os.path.join(os.environ['TESTS_PROJECT_ROOT'], os.environ['TESTS_MANIFEST'])
lang = tomllib.load(open(mf, 'rb'))['meta']['language']
assert lang in ('en', 'ru'), f'[meta].language must be en or ru, got {lang!r}'
print('OK')
" "ASSERT-MANIFEST-014: [meta].language in en or ru" "" "v0.1"

# ── Group 9: [pipeline.evaluation] present ────────────────────
# Not in the 7 required, but user-owned cross-cutting section.

assert_toml_field "$TESTS_MANIFEST" "pipeline.evaluation" "ASSERT-MANIFEST-015: [pipeline.evaluation] present (user-owned cross-cutting)"

# ── AC-7 stdlib guard ─────────────────────────────────────────
# AC-7 of REQ-VALID-001 forbids `pip install` / `requirements.txt`
# anywhere in this group. Assert it locally so a future contributor
# adding an external dep fails this script immediately.
#
# test-rules.sh is excluded because the assertions below mention
# those strings in their description / labels but never invoke them
# (descriptive text, not real dependencies). Any OTHER file under
# tests/manifest/ that introduces `pip install` or `requirements.txt`
# would still be caught.

if grep -rE 'pip install|requirements\.txt' tests/manifest --exclude='test-rules.sh' 2>/dev/null; then
    _log_fail "ASSERT-MANIFEST-016: tests/manifest/ contains no 'pip install' or 'requirements.txt' (REQ-VALID-001 AC-7)" \
              "remove external dependency, REQ-VALID-001 AC-7 is stdlib-only"
else
    _log_pass "ASSERT-MANIFEST-016: tests/manifest/ contains no 'pip install' or 'requirements.txt' (REQ-VALID-001 AC-7)"
fi

report_and_exit
