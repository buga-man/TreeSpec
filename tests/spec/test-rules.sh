#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tests/spec/test-rules.sh — spec L0 field rule assertions
#
# Source of truth: skills/tree-spec/documents/spec-format.md §6
# (L0 · REQUIRED fields).
#
# Each assert has a stable id (ASSERT-SPEC-NNN) so the rule catalog
# at documents/validation.md (EPIC-007) can reference it by id.
#
# Coverage map (17 asserts; 001-016 walk tests/_fixtures/biz-spec/REQ-*.md;
# 017 is a per-REQ verdict on the live REQ-EXEC-003.md, not a fixture walk):
#   001  id matches ^REQ-[A-Z]{2,8}-\d{3}$
#   002  id unique across the directory
#   003  title non-empty
#   004  title ≤120 characters
#   005  status ∈ {draft, approved, implemented, done}
#   006  type ∈ {feature, bug, refactor, chore, spike, compliance}
#   007  priority ∈ {critical, high, medium, low}
#   008  epic matches ^EPIC-\d{3}-[a-z][a-z0-9-]*$
#   009  scope.in non-empty
#   010  acceptance_criteria ≥1
#   011  AC ids unique within spec
#   012  provenance.created matches ^\d{4}-\d{2}-\d{2}$
#   013  provenance.updated matches ^\d{4}-\d{2}-\d{2}$
#   014  provenance.author non-empty
#   015  conditional — if source_refs present, every .path exists
#        (resolved relative to the spec file's directory, per
#        REQ-TRACE-001 AC-3 design)
#   016  AC-7 stdlib guard — no 'pip install' / 'requirements.txt'
#   017  REQ-EXEC-003 has a non-empty selection_criteria (EPIC-011 verdict)
# ════════════════════════════════════════════════════════════════

. "$(dirname "$0")/../_lib/common.sh"

section "spec — L0 field rules (matches documents/spec-format.md §6)"

SPEC_DIR="tests/_fixtures/biz-spec"

# ── Load helper — yields list of (filename, frontmatter_dict) tuples ──
# Each per-rule assert below calls _spec_load() via assert_python.

# ── Group 1: id matches regex ─────────────────────────────────
# Per spec-format.md §3: id format ^REQ-[A-Z]{2,8}-\d{3}$

assert_python "
import re, yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
pat = re.compile(r'^REQ-[A-Z]{2,8}-\d{3}\$')
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    sid = fm.get('id', '')
    assert pat.match(sid), f'{f.name}: id {sid!r} does not match ^REQ-[A-Z]{{2,8}}-\\d{{3}}\$'
print('OK')
" 'ASSERT-SPEC-001: id matches ^REQ-[A-Z]{2,8}-\d{3}$ (per spec-format.md §3)'

# ── Group 2: id unique across all specs ───────────────────────

assert_python "
import yaml, pathlib
from collections import Counter
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
ids = []
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    ids.append(fm.get('id', ''))
dups = [i for i, c in Counter(ids).items() if c > 1]
assert not dups, f'duplicate spec ids: {dups}'
print('OK')
" 'ASSERT-SPEC-002: id unique across tests/_fixtures/biz-spec/'

# ── Group 3: title non-empty ──────────────────────────────────

assert_python "
import yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    title = fm.get('title', '')
    assert isinstance(title, str) and title.strip(), f'{f.name}: title is empty or not a string'
print('OK')
" 'ASSERT-SPEC-003: title non-empty (per spec-format.md §6)'

# ── Group 4: title ≤120 characters ────────────────────────────

assert_python "
import yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    title = fm.get('title', '')
    assert isinstance(title, str) and len(title) <= 120, f'{f.name}: title length {len(title)} > 120'
print('OK')
" 'ASSERT-SPEC-004: title ≤120 characters (per spec-format.md §6)'

# ── Group 5: status enum ──────────────────────────────────────
# Per spec-format.md §5: 4 values: draft, approved, implemented, done

assert_python "
import yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
VALID = {'draft', 'approved', 'implemented', 'done'}
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    status = fm.get('status', '')
    assert status in VALID, f'{f.name}: status {status!r} not in {sorted(VALID)}'
print('OK')
" 'ASSERT-SPEC-005: status ∈ {draft, approved, implemented, done} (per spec-format.md §5)'

# ── Group 6: type enum ────────────────────────────────────────

assert_python "
import yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
VALID = {'feature', 'bug', 'refactor', 'chore', 'spike', 'compliance'}
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    t = fm.get('type', '')
    assert t in VALID, f'{f.name}: type {t!r} not in {sorted(VALID)}'
print('OK')
" 'ASSERT-SPEC-006: type ∈ {feature, bug, refactor, chore, spike, compliance}'

# ── Group 7: priority enum ────────────────────────────────────

assert_python "
import yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
VALID = {'critical', 'high', 'medium', 'low'}
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    p = fm.get('priority', '')
    assert p in VALID, f'{f.name}: priority {p!r} not in {sorted(VALID)}'
print('OK')
" 'ASSERT-SPEC-007: priority ∈ {critical, high, medium, low}'

# ── Group 8: epic regex ───────────────────────────────────────

assert_python "
import re, yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
pat = re.compile(r'^EPIC-\d{3}-[a-z][a-z0-9-]*\$')
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    epic = fm.get('epic', '')
    assert pat.match(epic), f'{f.name}: epic {epic!r} does not match ^EPIC-\\d{{3}}-[a-z][a-z0-9-]*\$'
print('OK')
" 'ASSERT-SPEC-008: epic matches ^EPIC-\d{3}-[a-z][a-z0-9-]*$'

# ── Group 9: scope.in non-empty ───────────────────────────────

assert_python "
import yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    scope_in = fm.get('scope', {}).get('in', [])
    assert isinstance(scope_in, list) and len(scope_in) >= 1, f'{f.name}: scope.in must be non-empty list'
    for item in scope_in:
        assert isinstance(item, str) and item.strip(), f'{f.name}: scope.in contains non-string or empty: {item!r}'
print('OK')
" 'ASSERT-SPEC-009: scope.in non-empty list of non-empty strings'

# ── Group 10: acceptance_criteria ≥1 ──────────────────────────

assert_python "
import yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    acs = fm.get('acceptance_criteria', [])
    assert isinstance(acs, list) and len(acs) >= 1, f'{f.name}: acceptance_criteria must be non-empty list, got {acs!r}'
print('OK')
" 'ASSERT-SPEC-010: acceptance_criteria non-empty (≥1 AC)'

# ── Group 11: AC ids unique within spec ───────────────────────

assert_python "
import yaml, pathlib
from collections import Counter
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    acs = fm.get('acceptance_criteria', [])
    ac_ids = [ac.get('id', '') for ac in acs if isinstance(ac, dict)]
    dups = [i for i, c in Counter(ac_ids).items() if c > 1]
    assert not dups, f'{f.name}: duplicate AC ids within spec: {dups}'
print('OK')
" 'ASSERT-SPEC-011: AC ids unique within each spec'

# ── Group 12: provenance.created YYYY-MM-DD ───────────────────

assert_python "
import re, yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
pat = re.compile(r'^\d{4}-\d{2}-\d{2}\$')
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    created = fm.get('provenance', {}).get('created', '')
    assert pat.match(str(created)), f'{f.name}: provenance.created {created!r} not YYYY-MM-DD'
print('OK')
" 'ASSERT-SPEC-012: provenance.created matches ^\d{4}-\d{2}-\d{2}$'

# ── Group 13: provenance.updated YYYY-MM-DD ───────────────────

assert_python "
import re, yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
pat = re.compile(r'^\d{4}-\d{2}-\d{2}\$')
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    updated = fm.get('provenance', {}).get('updated', '')
    assert pat.match(str(updated)), f'{f.name}: provenance.updated {updated!r} not YYYY-MM-DD'
print('OK')
" 'ASSERT-SPEC-013: provenance.updated matches ^\d{4}-\d{2}-\d{2}$'

# ── Group 14: provenance.author non-empty ─────────────────────

assert_python "
import yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    author = fm.get('provenance', {}).get('author', '')
    assert isinstance(author, str) and author.strip(), f'{f.name}: provenance.author is empty or non-string'
print('OK')
" 'ASSERT-SPEC-014: provenance.author non-empty'

# ── Group 15: source_refs.path resolution (conditional) ────────
# Per REQ-TRACE-001 AC-3: when source_refs is present, every
# referenced path must exist. Resolution is relative to the SPEC
# FILE's directory (paths may point to framework docs that live
# outside the target repo at this layout level).

assert_python "
import os, yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
specs = sorted((root / 'tests/_fixtures/biz-spec').glob('REQ-*.md'))
checked = 0
for f in specs:
    fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
    refs = fm.get('provenance', {}).get('source_refs', None)
    if refs is None:
        continue  # conditional — skip if absent
    assert isinstance(refs, list), f'{f.name}: source_refs must be a list if present'
    spec_dir = f.parent
    for i, ref in enumerate(refs):
        assert isinstance(ref, dict), f'{f.name}: source_refs[{i}] must be a dict'
        path = ref.get('path')
        assert path, f'{f.name}: source_refs[{i}].path missing'
        # Resolve relative to spec file's directory
        resolved = (spec_dir / path).resolve()
        assert os.path.exists(resolved), (
            f'{f.name}: source_refs[{i}].path {path!r} '
            f'does not exist (resolved to {str(resolved)!r})'
        )
        checked += 1
print(f'OK ({checked} source_refs checked)')
" 'ASSERT-SPEC-015: if source_refs present, every .path resolves (per REQ-TRACE-001 AC-3)'

# ── AC-7 stdlib guard ─────────────────────────────────────────
# Defends against future contributors adding external deps. Excludes
# test-rules.sh itself (the assertions above mention those strings in
# their description / labels).

if grep -rE 'pip install|requirements\.txt' tests/spec --exclude='test-rules.sh' 2>/dev/null; then
    _log_fail "ASSERT-SPEC-016: tests/spec/ contains no 'pip install' or 'requirements.txt' (REQ-VALID-001 AC-7)" \
        "remove external dependency, REQ-VALID-001 AC-7 is stdlib-only"
else
    _log_pass "ASSERT-SPEC-016: tests/spec/ contains no 'pip install' or 'requirements.txt' (REQ-VALID-001 AC-7)"
fi

# ── ASSERT-SPEC-017 — REQ-EXEC-003 declares a spec-level selection_criteria (verdict at epic init) ──
# EPIC-011's best-of-n / consensus modes are only usable if a verifiable
# selection criterion exists. This is a mechanical verdict, not a human
# judgement: the live REQ-EXEC-003.md must declare a non-empty
# selection_criteria, else spec validation fails and the epic cannot reach
# G_spec. Asserted on the live spec (not a fixture) because it is a
# per-REQ verdict, not a pattern check over all specs.

assert_python "
import yaml, pathlib
root = pathlib.Path('__PROJECT_ROOT__')
f = root / 'artifacts/global/biz-spec/REQ-EXEC-003.md'
assert f.exists(), f'REQ-EXEC-003.md not found at {f} — cannot give verdict'
fm = yaml.safe_load(f.read_text(encoding='utf-8').split('---', 2)[1])
crit = fm.get('selection_criteria', '')
assert isinstance(crit, str) and crit.strip(), (
    f'{f.name}: selection_criteria must be a non-empty string '
    f'(EPIC-011 verdict at epic init — best-of-n/consensus need a verifiable criterion)'
)
print('OK')
" 'ASSERT-SPEC-017: REQ-EXEC-003 declares a spec-level selection_criteria (verdict at epic init)'

report_and_exit
