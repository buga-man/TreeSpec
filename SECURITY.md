# Security Policy

This document is the public, mirrored copy of the project's security
disclosure policy. The **canonical** contact and the actual disclosure
process are described below — they do **not** depend on opening a public
issue.

## Supported versions

| Version | Supported |
| ------- | --------- |
| latest commit on `main` | ✅ |
| older commits           | ❌ |

## How to report a vulnerability

**Do not open a public issue.** Public issues are visible to attackers
before a fix is shipped.

Preferred channel: email **buga-man@users.noreply.github.com**
(GitHub provides a per-user noreply address that forwards privately).

Include:

- A short description of the vulnerability and its impact.
- Steps to reproduce, ideally with a minimal example.
- Affected commit SHA / file path / spec id (`REQ-…`).

You should hear back within **7 days**. If you don't, ping via a
[GitHub Discussions](https://github.com/buga-man/treespec-target/discussions)
thread — *without* disclosing the vulnerability.

## Disclosure timeline

- **Day 0** — report received, acknowledged.
- **Day ≤ 7** — triage decision: accepted / declined / needs more info.
- **Day ≤ 30** — fix shipped on a private branch, or a public timeline
  if a fix is not feasible.
- **Day ≤ 90** — public disclosure (advisory, CVE if applicable, fix in
  `main`).

## Scope

In-scope for this project:

- Anything that lets a third party bypass the agent's
  `[pipeline.evaluation]` rules (claim/verify, scope respect,
  evidence capture).
- Anything that lets a malicious spec / AC silently pass an oracle.
- Anything in `skills/` that runs code with the agent's privileges.

Out-of-scope:

- The host environment (Claude Code, Cursor, Windsurf, Aider). Report
  upstream.
- The user's own prompts / misuse.