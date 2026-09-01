# Repository protection — setup checklist

> Goal: make this repository **read-only for everyone except the owner**.
> Files in `.github/`, `CONTRIBUTING.md`, and `SECURITY.md` provide the
> *documented* protection. **Branch protection rules must be configured
> manually** in the GitHub UI — they cannot be set from inside the repo.

## Before you publish

1. **Verify the placeholder is gone.** A repo-wide grep for the literal
   `OWNER_HANDLE` should print nothing — this doc itself mentions the
   string only inside this very instruction, so allow that one match:

   ```bash
   grep -rn "OWNER_HANDLE" . --exclude-dir=.git
   # expected: 1 match in docs/REPOSITORY-PROTECTION.md (this line)
   ```

   If anything else matches, the substitutions were not done everywhere.

2. **Verify the owner is the right account.** Spot-check that
   `@buga-man` is the GitHub username you actually publish from — not a
   personal account, not an alt. CODEOWNERS matches by GitHub login,
   so a typo means nobody reviews PRs.

3. **Verify the README badges render.** Open `README.md` and confirm
   the `LICENSE` and `maintained` shields link to the right repo path.

## GitHub UI: settings to flip

### A. General

- **Visibility → Public.** Settings → General → Danger Zone → "Change
  repository visibility".

### B. Branches → Branch protection rules → `main`

Settings → Branches → "Add rule" for `main`:

| Setting | Value | Why |
| ------- | ----- | --- |
| Branch name pattern | `main` | match the default branch |
| Require a pull request before merging | ✅ | no direct pushes |
| Require approvals | `1` | only the owner reviews |
| Require review from Code Owners | ✅ | makes `@buga-man` mandatory |
| Dismiss stale pull request approvals on new commits | ✅ | force re-review after force-pushes in forks |
| Require status checks to pass before merging | (optional) | not needed for a docs-only repo |
| Require linear history | ✅ | forces rebase / squash; clean log |
| Require signed commits | (optional) | if you sign your commits |
| Include administrators | ✅ | even you can't bypass via the API |
| Allow force pushes | ❌ | block `--force` |
| Allow deletions | ❌ | block accidental `git push origin --delete main` |

### C. Branches → branch protection rules → `*` (catch-all)

If you ever create other long-lived branches (e.g. `release`), repeat
the above for `*` with the same settings.

### D. General → Pull Requests

- **Allow squash merging:** ✅ (default commit message = PR title).
- **Allow rebase merging:** ✅.
- **Allow merge commit:** ❌ — keeps history linear.
- **Always suggest updating pull request branches:** ✅.
- **Automatically delete head branches:** ✅ — keeps the branch list clean
  after merge.

### E. General → Archives (optional)

If you want to stop accepting **all** changes (issues + PRs), the repo
can be **archived**. After archive:

- The repo is read-only — no edits, no PRs, no issues.
- It can still be forked and read.

This is the strongest "no edits" option GitHub does, but it's a
**one-way door**: unarchiving requires a maintainer action.

## What GitHub does NOT let you disable

- **Forking** a public repo. Anyone with a GitHub account can fork a
  public repo. That's an architectural guarantee of GitHub and there is
  no setting to disable it for public repos. The "fork → PR" flow in
  `CONTRIBUTING.md` is the supported way to *accept* contributions.

  Closest mitigations if you want to discourage forks:
  - Mark the repo as archived (D, above) — forking still works, but the
    UI discourages contributions.
  - Disable Issues (Settings → General → Issues → off). Forks can still
    open PRs, just no public conversation channel.

- **Stars / watches / clones**. These are read-only signals and cannot
  be restricted.

## Operational notes

- **You are the only collaborator.** Don't add anyone as a
  collaborator — branch protection blocks forks but not collaborators.
  If you need help from someone specific, ask them to send a PR from a
  fork (the same flow as anyone else), and you stay the sole merger.

- **Confirming `@buga-man` is the only owner.** Spot-check the five
  files that reference the owner — they should mention `@buga-man`
  exactly where this checklist does:

  ```bash
  grep -rn "buga-man" .github CONTRIBUTING.md SECURITY.md docs/REPOSITORY-PROTECTION.md
  ```

- **Rotating the owner.** Change the GitHub username in CODEOWNERS (and
  in SECURITY.md / config.yml) before transferring the repo.

## Sanity check after publishing

After the repo is public:

1. From a second account (or a friend's account), open a test PR from a
   fork into `main`. Confirm GitHub:
   - Requires `@buga-man` review.
   - Blocks merging until the review is approved.
2. As the owner, attempt to push directly to `main`:

   ```bash
   git checkout main
   git commit --allow-empty -m "test: direct push should fail"
   git push origin main
   # → remote: error: GH006: Protected branch update failed
   ```

3. Verify issues use the new templates: open a test issue, choose
   "Bug report" from the chooser, confirm the form has the new fields.

All three should pass. If any fails, branch protection is not active —
re-check section B.