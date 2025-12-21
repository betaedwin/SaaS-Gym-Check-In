Phase 1: App Scaffold & Navigation
Flutter app initialized with an iOS-first layout
Core navigation shell established
Baseline app structure created
No business logic or domain behavior introduced
Carry-forward constraints:
Navigation structure must remain stable unless explicitly re-scoped
Phase 2A / 2B: Authentication & Profile Foundation
Supabase email/password authentication implemented
Profile row automatically created for each authenticated user
Safe recovery UX established; Retry signs user out cleanly
Infinite authentication loops prevented
Auth and profile lifecycle considered stable
Carry-forward constraints:
Auth and profile creation flows must not be altered by future phases
Phase 3A / 3B: Gym Check-In System
GPS-based gym check-in with radius validation
QR code fallback implemented for edge cases
Check-ins persisted with strict per-user RLS
Read-only check-in history available to members
Explicit handling for:
New users with zero check-ins
Users already checked in for the day
Loading, empty, and error states handled explicitly
No admin, edit, undo, or mutation capabilities introduced
Carry-forward constraints:
Check-ins are append-only, member-owned records with no client-side edits
Phase 4A: Class Schedule (Read-Only)
Backend-owned class schedule introduced via public.class_schedule
Authenticated, SELECT-only RLS enforced
Schedule displayed in the existing Schedule screen
Classes sorted by start time
Explicit loading, empty, and error states implemented
No client-side writes or mutations introduced
Carry-forward constraints:
Schedule remains informational context only; no booking, attendance, or interaction
Phase 5: Enhanced Member Profile (Attendance-Centered)
Profile upgraded to a read-only, attendance-centered snapshot
Identity data combined with derived attendance data
Members can view:
Total check-ins
Member since (earliest check-in date)
Recent activity summary
All surfaced data remains descriptive only
No evaluation, trends, comparisons, rankings, or motivational signals introduced
No new tables, writes, or RLS changes
Carry-forward constraints:
Profile must remain fully read-only with no gamification, goals, or performance framing
Phase 6: Shareable Training Snapshot (Static Artifact)
Member-initiated, shareable training snapshot implemented
Snapshot rendered as a single static image generated on demand
Snapshot summarizes derived data only:
Member since
Total check-ins (or equivalent neutral count)
Visual presentation is gym-branded and member-first
Sharing handled exclusively via OS-level share sheet
Snapshot represents a single moment in time
No social surfaces or engagement mechanics introduced
No new tables, writes, or RLS changes
Carry-forward constraints:
Shareable artifacts are static, opt-in, and self-referential
No social, comparative, or growth-driven behavior may be introduced
Phase 6A: UI Refinement & Visual Cohesion (Demo Readiness)
Non-functional UI refinement phase completed to prepare the MVP for gym-owner demo
Global UI style contract introduced to normalize:
Typography roles
Spacing rhythm
Color usage (Red / Black / White)
Profile screen visually re-composed into a single continuous surface
Attendance facts presented as vertically stacked, read-only records
Identity positioned as the primary visual anchor
Gym logo incorporated as a subtle, decorative brand element without competing with member identity
Same visual system propagated consistently to:
Login
Check-In
Schedule
All changes limited strictly to presentation
No new features, flows, interactions, or states introduced
No changes to navigation, data logic, calculations, or backend policies
Carry-forward constraints:
UI refinements must not introduce motivational, competitive, or performance signaling
Member-facing surfaces remain calm, pride-based, and descriptive
Visual system established in this phase should be preserved by future phases
No functional or behavioral changes may be bundled with visual polish