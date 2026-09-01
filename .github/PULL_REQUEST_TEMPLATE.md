<!--
  PR template — replaces the default GitHub template.
  Forces every contributor (including forks) to confirm authorship, scope,
  and licensing before review. Also signals that direct edits are not
  accepted: contributors must come from a fork.
-->

## Source

- [ ] This PR comes from a **fork** of this repository
- [ ] No direct commits to `main` were attempted (branch protection will block them anyway)

## What & why

<!-- One paragraph: what does this change and why is it needed? -->

## Scope

- [ ] Changes are limited to `scope.in` (or a clearly stated out-of-scope bug fix)
- [ ] No unrelated refactors, formatting, or file moves

## Verification

- [ ] Linked issue / spec (`REQ-…`) or described the problem in "What & why"
- [ ] Local checks pass (TOML parse, skill-path sanity, see README "Sanity check")
- [ ] If code changed: AC oracles pass; evidence attached or linked

## Licensing

- [ ] I agree this contribution is licensed under **OSL-3.0** (see `LICENSE.md`)
- [ ] I have the right to submit it under that license (no third-party code without attribution)

## Checklist for the owner

- [ ] Reviewer requested from `@buga-man` (CODEOWNERS should auto-request)
- [ ] Squash merge preferred; commit message references the spec/issue