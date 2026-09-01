# Contributing to TreeSpec Target

> **TL;DR.** This repo is **read-only for everyone except the owner**. You
> can report issues and send pull requests — but PRs can only come from
> a **fork**. Direct edits to this repository are not accepted.

## How to contribute

1. **Fork** the repository to your own GitHub account.
2. Create a branch in your fork: `git checkout -b fix/your-topic`.
3. Make your changes. Keep them focused; one PR = one concern.
4. Open a Pull Request **from your fork's branch into `main` here**.
5. Wait for review. The owner (`@buga-man` in `CODEOWNERS`) is the
   sole reviewer and merger.

> PRs that try to push directly to `main` will be rejected by branch
> protection — see `docs/REPOSITORY-PROTECTION.md` for how that's enforced.

## What we accept

- Bug fixes with a clear repro and a linked `REQ-…` spec (or a description
  that justifies opening a new one).
- Specs (L0 + AC with oracles) for new functionality.
- Documentation fixes (typos, broken links, clearer wording).
- Tooling that makes the kit easier to use, gated on the existing
  `[pipeline.evaluation]` rules (claim/verify, scope respect, etc.).

## What we don't accept

- Refactors without a stated motivation.
- Formatting-only PRs.
- Changes that bypass the manifest contract (e.g. editing
  `tree-spec.toml` without a spec).
- Code without an AC and an oracle.

## Process

- Every PR goes through the same gates the framework describes:
  `spec → plan → implement → verify`. A PR's description is its spec.
- The owner is the only person who can pass the human gates (`G_spec`,
  `G_plan`, `G_done`) — see `tree-spec.toml` § `[pipeline.gates]`.

## Reporting issues

Use the issue templates. For security, **do not** open a public issue —
see `SECURITY.md`.

## Licensing

By submitting a contribution, you agree it is licensed under
**OSL-3.0** (see `LICENSE.md`) and that you have the right to do so.