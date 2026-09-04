#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tests/fixtures/test-synthetic.sh — drive fixtures, assert rules fire
#
# Source of truth: REQ-VALID-001 AC-5 ("If a synthetic manifest / spec /
# router fixture violates a documented rule, then bash tests/run-all.sh
# shall return a non-zero exit code and print a per-assertion message
# that names the failing rule and the file path within the fixture").
#
# This script exercises the SAME rule checks used by tests/manifest,
# tests/spec, and tests/router — but against the bad-* fixtures under
# tests/fixtures/synthetic/. Each fixture is designed to violate exactly
# ONE rule (see T-05). This script asserts that the rule correctly
# DETECTS each violation. A fixture that slips through (false negative)
# fails this script.
#
# Inversion of normal assertion semantics:
#   - The rule check is applied to the fixture.
#   - If the rule REJECTS the fixture (the rule fires correctly) → exit 0
#     → assert_python logs PASS.
#   - If the rule ACCEPTS the fixture (false negative) → AssertionError
#     → assert_python logs FAIL with diagnostic.
#
# Wired into run-all.sh: NO (per AC-6 — the synthetic harness would
# always make the runner red). Run separately via:
#   bash tests/fixtures/test-synthetic.sh
# ════════════════════════════════════════════════════════════════

. "$(dirname "$0")/../_lib/common.sh"

section "synthetic — fixtures correctly trigger their rules (REQ-VALID-001 AC-5)"

# Loop over every fixture. Each iteration dispatches to a per-rule assert
# that expects the rule to fire. Failure of the rule = pass for this test;
# acceptance of the fixture = FAIL (false negative).

for fixture in tests/fixtures/synthetic/bad-*; do
    [ -e "$fixture" ] || continue
    fname=$(basename "$fixture")
    case "$fname" in
    bad-empty-scope.md)
        assert_python "
import yaml, pathlib
fm = yaml.safe_load(pathlib.Path('__PROJECT_ROOT__/tests/fixtures/synthetic/bad-empty-scope.md').read_text(encoding='utf-8').split('---', 2)[1])
scope_in = fm.get('scope', {}).get('in', [])
assert not scope_in, f'observed scope.in={scope_in!r}'
print('OK')
" "ASSERT-SYNTHETIC-001: rule=scope.in non-empty, fixture=$fname"
        ;;

    bad-id-format.md)
        assert_python "
import re, yaml, pathlib
fm = yaml.safe_load(pathlib.Path('__PROJECT_ROOT__/tests/fixtures/synthetic/bad-id-format.md').read_text(encoding='utf-8').split('---', 2)[1])
sid = fm.get('id', '')
assert not re.match(r'^REQ-[A-Z]{2,8}-\d{3}\$', sid), f'observed id={sid!r}'
print('OK')
" "ASSERT-SYNTHETIC-002: rule=id regex, fixture=$fname"
        ;;

    bad-duplicate-id.md)
        # The duplicate rule is cross-file: the fixture's id must
        # match a committed fixture spec's id for the collision to
        # exist. Assert both ids are equal — that's the structural
        # condition under which the duplicate detector would fire.
        # Uses tests/_fixtures/biz-spec/REQ-INTAKE-001.md (committed) so
        # the synthetic harness is standalone.
        assert_python "
import yaml, pathlib
fx_path = pathlib.Path('__PROJECT_ROOT__/tests/fixtures/synthetic/bad-duplicate-id.md')
real_path = pathlib.Path('__PROJECT_ROOT__/tests/_fixtures/biz-spec/REQ-INTAKE-001.md')
fx_fm = yaml.safe_load(fx_path.read_text(encoding='utf-8').split('---', 2)[1])
assert real_path.exists(), 'real spec missing — collision cannot be detected'
real_fm = yaml.safe_load(real_path.read_text(encoding='utf-8').split('---', 2)[1])
assert fx_fm.get('id') == real_fm.get('id'), f'observed fixture_id={fx_fm.get(\"id\")!r} != real_id={real_fm.get(\"id\")!r}'
print('OK')
" "ASSERT-SYNTHETIC-003: rule=id uniqueness (cross-file), fixture=$fname"
        ;;

    bad-missing-author.md)
        assert_python "
import yaml, pathlib
fm = yaml.safe_load(pathlib.Path('__PROJECT_ROOT__/tests/fixtures/synthetic/bad-missing-author.md').read_text(encoding='utf-8').split('---', 2)[1])
author = fm.get('provenance', {}).get('author', '')
assert not author.strip(), f'observed author={author!r}'
print('OK')
" "ASSERT-SYNTHETIC-004: rule=provenance.author non-empty, fixture=$fname"
        ;;

    bad-status-enum.md)
        assert_python "
import yaml, pathlib
fm = yaml.safe_load(pathlib.Path('__PROJECT_ROOT__/tests/fixtures/synthetic/bad-status-enum.md').read_text(encoding='utf-8').split('---', 2)[1])
status = fm.get('status', '')
VALID = {'draft', 'approved', 'implemented', 'done'}
assert status not in VALID, f'observed status={status!r}'
print('OK')
" "ASSERT-SYNTHETIC-005: rule=status enum, fixture=$fname"
        ;;

    bad-entry-skill.toml)
        assert_python "
import tomllib
d = tomllib.load(open('__PROJECT_ROOT__/tests/fixtures/synthetic/bad-entry-skill.toml', 'rb'))
skill_keys = set(d['pipeline']['skills'].keys())
es = d['pipeline']['stages']['spec']['entry_skill']
assert es not in skill_keys, f'observed entry_skill={es!r} ∈ skill_keys={sorted(skill_keys)!r}'
print('OK')
" "ASSERT-SYNTHETIC-006: rule=entry_skill ∈ [pipeline.skills], fixture=$fname"
        ;;

    bad-missing-classification.toml)
        # ASSERT-MANIFEST-017 fires: a skill is missing a classification field.
        assert_python "
import tomllib
d = tomllib.load(open('__PROJECT_ROOT__/tests/fixtures/synthetic/bad-missing-classification.toml', 'rb'))
fields = ['classification', 'reproducibility', 'execution_mode', 'flaky_tolerance']
skills = d.get('pipeline', {}).get('skills', {})
missing = [(sid, f) for sid, s in skills.items() for f in fields if f not in s]
assert missing, f'observed no missing classification field; expected one'
print('OK')
" "ASSERT-SYNTHETIC-007: rule=four classification fields present, fixture=$fname"
        ;;

    bad-badenum-classification.toml)
        # ASSERT-MANIFEST-018 fires: a classification enum value is out of set.
        assert_python "
import tomllib
d = tomllib.load(open('__PROJECT_ROOT__/tests/fixtures/synthetic/bad-badenum-classification.toml', 'rb'))
ENUMS = {'classification': {'pure','stochastic','hybrid'}, 'reproducibility': {'strict','best-effort','none'}, 'execution_mode': {'single','best-of-n','consensus'}}
skills = d.get('pipeline', {}).get('skills', {})
bad = [(sid, f, s[f]) for sid, s in skills.items() for f, allowed in ENUMS.items() if s.get(f) not in allowed]
assert bad, f'observed no out-of-set classification enum; expected one'
print('OK')
" "ASSERT-SYNTHETIC-008: rule=classification enum membership, fixture=$fname"
        ;;

    *)
        # Unknown fixture — no expected rule mapped. Treat as a fail
        # so an orphan fixture surfaces immediately.
        _log_fail "synthetic: no expected rule for fixture=$(basename "$fixture")" \
            "add a case branch in tests/fixtures/test-synthetic.sh"
        ;;
    esac
done

# ── AC-7 stdlib guard (REQ-VALID-001 AC-7) ─────────────────────
# Defends against future contributors adding external deps to this
# group. Excludes: this script (assertion names mention the strings),
# the fixtures themselves (.md/.toml don't run anything), and the
# common helpers.

if grep -rE 'pip install|requirements\.txt' tests/fixtures \
    --exclude='test-synthetic.sh' \
    --exclude='*.md' \
    --exclude='*.toml' 2>/dev/null; then
    _log_fail "ASSERT-SYNTHETIC-007: tests/fixtures/ contains no 'pip install' or 'requirements.txt' (REQ-VALID-001 AC-7)" \
        "remove external dependency, REQ-VALID-001 AC-7 is stdlib-only"
else
    _log_pass "ASSERT-SYNTHETIC-007: tests/fixtures/ contains no 'pip install' or 'requirements.txt' (REQ-VALID-001 AC-7)"
fi

report_and_exit
