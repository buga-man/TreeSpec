# brainstorm — mock scenarios

## Scenario 1: simple idea, no source_doc

**Input:**
```
brainstorm(
    idea="add password reset via email",
    context=None,
    source_doc=None,
)
```

**Expected dialogue:** 3–7 questions from the list in Step 2.
**Expected output:** one L0 draft with `id=REQ-AUTH-NNN`, `status=draft`,
`scope.in = ["email-based reset", "1-hour token TTL"]`, etc.

## Scenario 2: bulk source_doc

**Setup:** `source_doc = "backlog/auth.md"` containing 5 BR items:

```markdown
# Auth backlog
BR-1  Reset password via email
BR-2  Rate-limit login at 5/min/IP
BR-3  Audit log for sensitive ops
BR-4  OAuth2 with Google provider
BR-5  Session timeout after 30 days idle
```

**Expected behaviour:**
1. Agent reads file, extracts 5 candidates.
2. Agent asks: "Found 5 candidates. Spec which one? (1, 2, 3, 4, 5, all)"
3. User picks one (say, BR-3).
4. Dialogue proceeds with "audit log for sensitive ops" as the focus.
5. One L0 draft for `REQ-AUDIT-NNN`.

## Scenario 3: vague prose source_doc

**Setup:** `source_doc = "workshop-notes.md"` containing:

```markdown
The team wants better security and faster onboarding. Maybe add MFA
sometime. The dashboard should be more useful. Compliance is important.
```

**Expected behaviour:**
- The agent reports `on_source_doc_too_vague` and lists the unclear
  candidates ("better security", "faster onboarding", "more useful
  dashboard", "compliance"). It does NOT fabricate L0 fields.
- Asks the human to disambiguate or rewrite.

## Scenario 4: conflict with existing REQ

**Setup:** `artifacts/global/biz-spec/` already has `REQ-AUTH-007`
("Login form validates email format"). The brainstorm draft suggests a
new `REQ-AUTH-008` that contradicts it.

**Expected behaviour:**
- Brainstorm flags the conflict in its output (`conflicts` field in
  the draft).
- Does NOT silently adjust the draft.
- Hands off to `write-spec`, which creates `docs/conflict-NNN.md`.