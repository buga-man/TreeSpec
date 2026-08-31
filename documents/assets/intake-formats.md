# Intake Format Conventions

Extraction heuristics for typical raw source types, used by the `intake`
skill. Phase 0: documented conventions only — no parsers, no runtime.

## BR/US lists (numbered requirements / user stories)

- Each numbered item = one candidate row.
- Anchor: the item id or number (e.g., "BR-7", "US-12").
- User story "As a X, I want Y, so that Z" → Text is the Y clause;
  the Z clause may enrich it.

## Jira export (CSV / JSON)

- One issue = one candidate row (skip non-requirement types: epics,
  sub-tasks, chores).
- Anchor: the issue key (e.g., "PROJ-123").
- Text from summary + acceptance criteria; ignore comment chatter unless
  it clarifies the requirement.

## Confluence / prose pages

- Scan headings and lists per section; each concrete statement = one
  candidate.
- Anchor: page path + heading.
- Vague statements ("improve performance") → low confidence, flag for
  human clarification.

## Chat transcripts

- Extract only decisions and commitments ("let's do X", "we need Y");
  ignore discussion noise.
- Anchor: message timestamp or thread reference.
- Group related messages expressing the same requirement into one
  candidate; confidence usually low/medium.
