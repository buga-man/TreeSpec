#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tests/manifest/test-rules.sh — manifest v0.2 rule assertions
#
# Source of truth: documents/concepts/10-manifest.md (CON-10) +
# tree-spec.toml [pipeline.skills.tree-spec] validation procedure
# (skills/tree-spec/SKILL.md § "Validation (fail-closed)").
#
# Each assert has a stable id (ASSERT-MANIFEST-NNN) so the rule
# catalog at documents/validation.md (EPIC-007) can reference it.
#
# Coverage map (15 asserts):
#   001..007  7 required sections
#   008       [kernel].version matches semver (phase 0 strict)
#   009       [identity].name matches kebab-case
#   010       [pipeline.skills.*].file resolves under skills/tree-spec/
#   011       [pipeline.stages.*].entry_skill ∈ [pipeline.skills]
#   012       [pipeline.gates.*].participants[kind=skill].id ∈ [pipeline.skills]
#   013       [epic] key present (machine-maintained but required)
#   014       [meta].language ∈ {"en", "ru"}
#   015       [pipeline.evaluation] present (extra user-owned section)
# ════════════════════════════════════════════════════════════════

. "$(dirname "$0")/../_lib/common.sh"

section "manifest — v0.2 rules (CON-10 + router validation)"

# ── Group 1: 7 required sections ──────────────────────────────
# Each assert confirms the TOML table path exists. tomllib walks
# `d['pipeline']['stages']` etc.; missing parents raise KeyError, the
# helper captures the error and counts it as a failure.

assert_toml_field "tree-spec.toml" "identity"         "ASSERT-MANIFEST-001: [identity] present"
assert_toml_field "tree-spec.toml" "kernel"           "ASSERT-MANIFEST-002: [kernel] present"
assert_toml_field "tree-spec.toml" "meta"             "ASSERT-MANIFEST-003: [meta] present"
assert_toml_field "tree-spec.toml" "pipeline"         "ASSERT-MANIFEST-004: [pipeline] present"
assert_toml_field "tree-spec.toml" "pipeline.stages"  "ASSERT-MANIFEST-005: [pipeline.stages] present"
assert_toml_field "tree-spec.toml" "pipeline.skills"  "ASSERT-MANIFEST-006: [pipeline.skills] present"
assert_toml_field "tree-spec.toml" "pipeline.gates"   "ASSERT-MANIFEST-007: [pipeline.gates] present"

# ── Group 2: kernel.version semver (phase 0 strict) ───────────

assert_python "
import re, tomllib
v = tomllib.load(open('__PROJECT_ROOT__/tree-spec.toml', 'rb'))['kernel']['version']
assert re.match(r'^0\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?\$', v), f'kernel.version not semver: {v!r}'
print('OK')
" "ASSERT-MANIFEST-008: [kernel].version matches semver (^0\\.[0-9]+\\.[0-9]+(-[A-Za-z0-9.-]+)?\$)"

# ── Group 3: identity.name kebab-case ─────────────────────────

assert_python "
import re, tomllib
n = tomllib.load(open('__PROJECT_ROOT__/tree-spec.toml', 'rb'))['identity']['name']
assert re.match(r'^[a-z][a-z0-9-]*\$', n), f'identity.name not kebab-case: {n!r}'
print('OK')
" "ASSERT-MANIFEST-009: [identity].name matches kebab-case (^[a-z][a-z0-9-]*\$)"

# ── Group 4: [pipeline.skills.*].file resolves to a real file ─
# Per [pipeline.stages.spec] exit_criteria + the router's validation
# step 2 (file paths). Each `[pipeline.skills.<id>].file` is relative
# to skills/tree-spec/ (the skill root for the v0.2 packaged layout).

assert_python "
import os, tomllib
root = '__PROJECT_ROOT__'
skills_root = os.path.join(root, 'skills', 'tree-spec')
skills = tomllib.load(open(os.path.join(root, 'tree-spec.toml'), 'rb'))['pipeline']['skills']
for sid, sdata in skills.items():
    f = sdata['file']
    full = os.path.join(skills_root, f)
    assert os.path.isfile(full), f'skill {sid}: file not found at {full!r}'
print('OK')
" "ASSERT-MANIFEST-010: every [pipeline.skills.*].file resolves under skills/tree-spec/"

# ── Group 5: [pipeline.stages.*].entry_skill ∈ [pipeline.skills] ─

assert_python "
import os, tomllib
root = '__PROJECT_ROOT__'
d = tomllib.load(open(os.path.join(root, 'tree-spec.toml'), 'rb'))
skill_keys = set(d['pipeline']['skills'].keys())
for stage, sdata in d['pipeline']['stages'].items():
    es = sdata.get('entry_skill')
    assert es is not None, f'stage {stage!r}: entry_skill missing'
    assert es in skill_keys, f'stage {stage!r}: entry_skill {es!r} not in [pipeline.skills] keys'
print('OK')
" "ASSERT-MANIFEST-011: every [pipeline.stages.*].entry_skill ∈ [pipeline.skills]"

# ── Group 6: gates.participants[kind=skill].id ∈ [pipeline.skills] ─

assert_python "
import os, tomllib
root = '__PROJECT_ROOT__'
d = tomllib.load(open(os.path.join(root, 'tree-spec.toml'), 'rb'))
skill_keys = set(d['pipeline']['skills'].keys())
for gate, gdata in d['pipeline']['gates'].items():
    participants = gdata.get('participants', [])
    assert isinstance(participants, list), f'gate {gate!r}: participants must be an array'
    for p in participants:
        if not isinstance(p, dict):
            continue  # tomllib may return list of dicts; tolerate entries
        if p.get('kind') == 'skill':
            assert p.get('id') in skill_keys, (
                f'gate {gate!r}: participant skill id {p.get(\"id\")!r} not in [pipeline.skills] keys'
            )
print('OK')
" "ASSERT-MANIFEST-012: every gate participant of kind=skill has id ∈ [pipeline.skills]"

# ── Group 7: [epic] key present ───────────────────────────────
# Machine-maintained pointer (recomputed from artifacts/INDEX.md at
# router start); the key itself must exist.

assert_toml_field "tree-spec.toml" "epic" "ASSERT-MANIFEST-013: [epic] key present (machine-maintained pointer)"

# ── Group 8: [meta].language whitelist ────────────────────────

assert_python "
import os, tomllib
root = '__PROJECT_ROOT__'
lang = tomllib.load(open(os.path.join(root, 'tree-spec.toml'), 'rb'))['meta']['language']
assert lang in ('en', 'ru'), f'[meta].language must be en or ru, got {lang!r}'
print('OK')
" 'ASSERT-MANIFEST-014: [meta].language ∈ {"en", "ru"}'

# ── Group 9: [pipeline.evaluation] present ────────────────────
# Not in the 7 required, but user-owned cross-cutting section.

assert_toml_field "tree-spec.toml" "pipeline.evaluation" "ASSERT-MANIFEST-015: [pipeline.evaluation] present (user-owned cross-cutting)"

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
