# intake — mock scenarios

## Scenario 1: multi-source ingestion

**Setup:** two raw sources exist:

- `backlog/auth.md`:
  ```markdown
  # Auth backlog
  BR-1  Reset password via email
  BR-2  Rate-limit login at 5/min/IP
  ```
- `notes/workshop-security.md` (prose):
  ```markdown
  Sensitive operations (create, delete, export) must be audit-logged.
  ```

**Input:**
```
intake(raw_sources=["backlog/auth.md", "notes/workshop-security.md"])
```

**Expected behaviour:**
1. Buffer `artifacts/intake/REQUIREMENTS.md` is created (Step 0) or
   read (if it exists).
2. Three candidate rows are appended: C-NNN for BR-1, BR-2, and the
   audit-log requirement — each with Text, Source ref (path + anchor),
   Domain, Status=candidate, Confidence.
3. Handoff lists the new Cand-IDs. No draft is produced (that is
   `brainstorm`'s job).

## Scenario 2: re-ingesting an already-known source

**Setup:** `backlog/auth.md` was ingested in Scenario 1; the buffer
already holds rows for BR-1 and BR-2. A new line BR-3 is appended to
the file.

**Input:**
```
intake(raw_sources=["backlog/auth.md"])
```

**Expected behaviour:**
- The agent checks the buffer first (Step 1): only BR-3 is genuinely
  new, so exactly one row is appended. No duplicate rows for BR-1/BR-2.

## Scenario 3: overlap detection

**Setup:** the buffer already contains C-004 "Rate-limit login attempts"
(domain AUTH). The new source `backlog/security.md` says
"Limit login to 5 attempts per minute per IP".

**Expected behaviour:**
- Step 3 detects the overlap and flags the new row as
  `duplicate of C-004` in its Text.
- The agent reports the flag in the handoff and does NOT merge or
  discard either row — the human decides which stands.

## Scenario 4: human-gated selection

**Setup:** buffer holds C-001..C-005 (all `candidate`).

**Expected behaviour:**
- Intake never marks a candidate `selected` on its own and never starts
  drafting from one.
- Only when the human says "spec out C-003" does the status move to
  `selected`, and exactly that candidate is handed to `brainstorm`.
- One run = one draft: selecting three candidates means three separate,
  explicitly confirmed handoffs — not a silent batch.
