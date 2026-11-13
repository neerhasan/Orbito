# Version 2 (second build): features on hold

Created 2026-11-13. These features are not built in v1. The founder asked to hold them for the second build. Do not build any of them before the founder says v2 starts.

## Moved out of v1 by the founder
These three were first-release (P0) features and the old milestone M4 ("guidance"). On 2026-11-13 the founder moved them to v2.

| ID | Feature | What it does |
|---|---|---|
| F-08 | Energy modes | Low, medium and high energy modes, each with its own saved routine. One tap to switch. Low mode shows only what matters now. |
| F-09 | Basic life score | A score for each life area and an overall Life line that always shows the real position. Says clearly when there is too little data. The placeholder formula is habits 40%, goals 40%, self-check 20%, with stages Starting 0-39, Building 40-64, Established 65-84, Thriving 85+. The founder still has to approve the formula. |
| F-10 | Fail-day next step | After a missed day, one small suggested step and a summary of progress so far. Encouraging and factual, never shaming. The founder reviews the wording before it is built. |

Full descriptions and acceptance criteria stay in `docs/product/Feature-Specification.md` (sections F-08, F-09, F-10).

What this changes in v1:
- The Today dashboard (M3) has no energy-mode switcher and no Life line section.
- Settings has no energy-mode routines.
- No score, no score history and no fail-day message in v1.
- The `energy_routine`, `routine_item` and `score_snapshot` tables are not created in v1.

## Shown in the designs but left out of M2 (2026-11-13)
The M2 designs and the prototype show these. They are not in the first-release spec, so they wait for a later version unless the founder asks for them in v1.
- Logging distractions during a focus session, and the Time page that sums them up.
- A habit that fills itself in from the sleep log (for example "Wake by 7:00").
- A reason for a missed habit ("What got in the way?").
- The "Patterns" box on Habits and "Connected to" on Sleep (these are insights, F-12).
- Repeating tasks that count as habits.
- Sleep from a watch or phone ("Device sync").
- Subtasks and "Up next" in focus mode.
- On the Today page (M3 design): Schedule with time blocks, Reminders, meetings, the Life line and Life area scores (with F-09), Insights (F-12) and Notes (F-13).

## Already planned for later (P1 and P2, from the Feature Specification)
These were never part of v1.
- F-12 Insights and 14-day tests
- F-13 Notes
- F-15 Calendar sync
- F-16 Trial and subscription billing
- F-17 Free and premium split
- F-18 Analytics and reports
- F-19 Web version
- F-20 Apple Watch
- F-21 AI helpers
- F-22 More integrations
- F-23 Sharing
- F-24 Post-beta additions
- F-25 Apple versions (Mac, iPhone, iPad)
- F-26 Widgets for Windows, Android and iOS (added by the founder on 2026-11-13, see below)

## Widgets (F-26): keep room open
The founder wants widgets on Windows, Android and iOS in a future version. Nothing is built for this in v1. What it means for v1:
- Keep the data and the rules (reading tasks, habits and so on) in the repositories and `lib/domain/`, apart from the screens, so a widget can reuse them later.
- Widgets are small native pieces on each system (home-screen widget on Android, widget on iOS, a widget for the Windows widgets board). They will read the same local data. How exactly is decided when the feature is specified.
- The iOS widget needs the Apple release (F-25), a Mac and the $99 per year membership. Windows and Android widgets can come first.
- This feature goes through the Feature Specification (full description and acceptance criteria) before it is built. What the widgets show (for example today's tasks, habits or the focus timer) is still to be decided with the founder.

## Open items for v2
- Score formula and stage names (founder to approve).
- Wording of the fail-day messages (founder to review).
- The ADHD test in the closed beta: does showing the real score help or discourage? v1 does not show a score, so this test moves to v2.
- Design for energy modes and the fail-day step (not yet designed; see `docs/design/DESIGN-NOTES.md`).
