Codex Prompt — {PHASE} Bug Fix (copy-paste)

You are a senior Flutter engineer debugging an existing iOS-first MVP app.

## Context
- Flutter app with Supabase backend
- Supabase Auth + Postgres + RLS already configured
- State management already chosen in repo (DO NOT change frameworks)

## Completed Phases
{LIST PHASES}

---

## Bug Observed
- Scenario: {who does what}
- Expected behavior: {what should happen}
- Actual behavior: {what happens instead}
- Evidence: {logs, screenshots, reproduction steps}

---

## Goal
Identify and fix the root cause of the bug.

---

## Investigation Requirements
Inspect the flow triggered by:
- {BUTTON / ACTION}

Identify async paths that:
- never resolve
- throw but are not caught
- return early without clearing loading state

Pay special attention to:
- empty Supabase query results
- “already exists” or “already done” logic
- early returns before state cleanup

---

## Fix Criteria (Must satisfy all)
{Concrete success conditions}

---

## Constraints
- Do NOT change database schema
- Do NOT change RLS policies
- Do NOT weaken business rules
- Do NOT refactor unrelated logic

---

## Deliverables
- Code changes
- List of files modified
- Brief explanation of root cause and fix

Begin debugging and fixing now.
