# Jiujitsu App — Project Constitution

## Purpose
Build a mobile app for a local jiujitsu gym that allows members to:
- Check in at the gym using GPS (with QR fallback)
- View their attendance history
- View gym-related information (e.g. class schedule)

This app is member-facing only.

---

## Tech Stack
- Flutter (iOS-first, Android supported)
- Supabase backend:
  - Supabase Auth
  - Postgres
  - Row Level Security (RLS)
- State management: use the existing solution in the repo (DO NOT change)

Supabase client is initialized at app startup.
Supabase URL and anon key live in `lib/core/app_config.dart` (or equivalent).

---

## Architectural Rules (Hard)
- Do NOT change the chosen state management framework
- Do NOT refactor unrelated logic
- Keep changes incremental and localized
- Prefer explicit, readable code over abstraction
- Favor correctness over cleverness

---

## Product Philosophy
- Phases are small and scoped
- Data visibility comes before actions
- Read-only means truly read-only
- No speculative features

---

## Explicit Non-Goals (Until Explicitly Introduced)
- No class booking
- No payments
- No admin UI
- No push notifications
- No analytics dashboards
- No feature flags
- No offline-first behavior

---

## Security Rules
- All data access must be protected by RLS
- Clients may only read or write what the phase explicitly allows
- Never weaken existing RLS policies

---

## Phase Discipline
Each phase must:
- Have a single clear goal
- Define IN SCOPE and OUT OF SCOPE explicitly
- Define loading, empty, and error states
- End with a phase summary before moving on
