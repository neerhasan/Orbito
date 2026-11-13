# Project Status
Project: Orbito | Version: 0.1 | Date: 2026-11-08
Status: IN PROGRESS

## Project overview
Name change (2026-11-11): the app is now called Orbito (previously Life System). Product documents have been updated. Earlier design screens, the working prototype and the old blueprint still show "Life System" and must be renamed. Name availability (app stores, domain, trademark) has not been confirmed.
Orbito (formerly called Life System) is a cross-platform personal life operating system for one person. It combines planning (life areas, goals, projects, tasks, notes, calendar) with daily tracking (habits, sleep, focus time, distractions) and an intelligence layer that finds patterns and likely root causes in the user's own data. Every insight is labelled as fact, correlation, hypothesis or recommendation. The first platform is Windows, followed by Android, iOS, macOS and the web.

This status file was created on 2026-11-08, when the project adopted the 12-phase gated workflow. Earlier work was done before this workflow existed. It is recorded below against the phase it belongs to, and none of it counts as an approved phase.

## Current phase / current milestone
Approval gates PAUSED at the founder's instruction (2026-11-11). The founder will build and test an initial version (v1) first, then review and change the documents and design from a list of problems found while testing.
Working mode until v1 is tested: follow the approved documents (PRD 0.4, Feature-Specification 0.3, User-Flows 0.2, Technology-Stack 0.5, System-Architecture 0.1) and the existing screen designs. Phase 05 (design) is not formally approved; the existing screens are used as they are. Still kept: Git for every change, testing each milestone before moving on, and this status file.
Current milestone: set up the project (Phase 06) and prove sign-in and sync between a Windows PC and an Android phone (architecture milestone M0).
After v1 testing: collect the founder's change list, update the documents (standing rule), and restart the approval gates from the first document that changes.

## Completed phases
None are approved.

| Phase | Status | Notes |
|---|---|---|
| 01 Idea Discovery and Requirements | APPROVED (2026-11-10) | Concept summary approved. Condition: keep room for new features after the beta launch. |
| 02 Product Documentation | APPROVED (version 0.2, 2026-11-11) | PRD, Feature Specification and User Flows approved; later platform and $0-launch changes approved with the stack. |
| 03 Technology Research and Selection | APPROVED (2026-11-11, Technology-Stack.md 0.5) | Flutter, SQLite with Drift, Supabase, PowerSync. |
| 04 System Architecture | APPROVED (2026-11-11, System-Architecture.md 0.1) | System-Architecture.md 0.1 written. The two early diagrams of 6 November (Redis, Node.js, Tauri) are superseded by it. |
| 05 UI/UX Design | IN PROGRESS (resumed 2026-11-11) | See "Work done before the gated workflow" below. |
| 06 Development Environment Setup | NOT STARTED | |
| 07 AI-Assisted Development | NOT STARTED | The HTML prototype is a design and usability prototype, not production code. |
| 08 Backend, Database and Integration | NOT STARTED | |
| 09 Quality Assurance and Testing | NOT STARTED | |
| 10 Beta Testing | NOT STARTED | |
| 11 Production Release | NOT STARTED | |
| 12 Post-Launch Maintenance | NOT STARTED | |

### Work done before the gated workflow (kept, not approved)
- **Design system:** a Life System design system ("Ember UI") on claude.ai, with colour, type, spacing and radius tokens taken from the Figma dashboard draft.
- **Design canvas:** "Life System – Today dashboard" on claude.ai, containing the Today dashboard and about 36 further screens. These cover the Quick Launcher, authentication, setup, tasks, habits, focus, sleep, inbox, upcoming, calendar, goals, projects, life areas, notes, time, analytics, insights, settings, system states and two mobile Today options. On 5 November the user confirmed the Today dashboard's design direction. That was direction feedback, not approval of Phase 05.
- **Working prototype:** "Life System" on claude.ai, a single-page web prototype with example data saved with the page. It covers tasks (with completion chart, grouping, filters, month view and project colours), habits, focus timer, sleep, inbox, goals, projects, life areas, notes, time, computed insights, 14-day tests and the Quick Launcher. Its purpose is to test the daily flow. It will not become production code.
- **Diagrams:** diagrams/life-system-architecture and diagrams/life-system-frontend, in PNG, SVG, DOT and MD.

## Standing condition from the user (2026-11-10)
The product must stay open to adding features in the future, for example after the beta launch. This is handled by: a P2 backlog in the Feature Specification, a modular design requirement in the PRD, and the Phase 12 rule that every new feature returns to Phase 02.

## Standing instruction from the user (2026-11-11)
If a feature or decision added later contradicts a previously approved document, update that document (and record the change in this file). Documents are revised to a new version number and shown to the founder for re-approval of the changed parts only.

## Pending phases
Phases 01 to 12, in order. Phase 05 design iteration, including the Tasks page revisions started on 6 November, resumes after Phases 01 to 04 are approved.

## Approved technical decisions
Architecture approved 2026-11-11 (System-Architecture.md 0.1): local-first app, PowerSync sync, Supabase with per-user access rules, no custom server in the first release. Open: sign-in method (proposed email and password), conflict rule (proposed latest change wins).

Approved 2026-11-11 (Technology-Stack.md 0.5):
- App framework: Flutter (Windows and Android first; Apple versions later).
- On-device storage: SQLite through Drift.
- Server, database and sign-in: Supabase (PostgreSQL).
- Sync engine: PowerSync.
- Initial release: closed test with friends at $0 on free plans; paid plans (about $74 per month) before public sales.
- Distribution for the test: direct sharing; Google Play and Microsoft Store optional.

## Phase 01 decisions recorded (stated by the user on 2026-11-08, pending approval of the concept summary)
1. **Business model:** freemium subscription. Personal use first. Sales begin only when the app is fully functional.
2. **Trial structure:** 1-month free trial with all premium features. After the trial, premium features are turned off and the free tier remains.
3. **Platforms (revised 2026-11-11):** the first release is for Windows and Android only. Mac, iPhone and iPad come later, after all features are confirmed. Apple users remain the main long-term market. The founder owns Windows and Android devices only. Flutter is proposed so Apple versions can be added later from the same codebase. Web: not decided.
4. **Apple hardware risk:** deferred to the later Apple release. Building and publishing Apple apps needs a Mac and a $99 per year membership; a plan for testing is needed then.
4b. **Initial release (2026-11-11):** a closed test with the founder's friends, launched at $0 on free plans. Paid plans are expected before public sales.
5. **Competitors named by the user:** Notion (personal task and life management), Todoist, TickTick, Notion Calendar, "Cal" (product not confirmed), Sunsama, Akiflow, Morgen. Researched additions for the ADHD segment: Tiimo, Inflow, Structured, Finch, Routinery. No researched competitor found so far combines life areas, goals, tracking and cause-finding insights in one app (to be verified before the summary).
6. **Target customer:** people with ADHD are the largest expected customer group (stated by the user). Market size and willingness to pay not yet verified.
7. **Positioning:** general life app with ADHD-friendly design and features (not an ADHD-only app).
8. **Dashboard:** customizable. A settings list lets users toggle which dashboard sections they see.
9. **Showing the real position:** the app shows the user's true score and position. The user's reasoning is that people cannot improve without knowing where they stand. On a failed day the app shows what to do next, and shows how far the user has come. Guided by "1% better every day", Atomic Habits and Psycho-Cybernetics identity-shift ideas. Assumption to test in beta: this does not discourage ADHD users.
10. **Energy modes:** low, medium and high energy, each with its own routine (three separate routines).
11. **Closest existing apps found (light research, sources partly biased):** Xenith, Discy, Evident (iPhone only), Exist, Gyroscope, Bearable, LifeWheel. None confirmed to combine planning, tracking and cause-finding insights in one app.
12. **Success criteria (first year):** (a) the app works for the founder daily for 90 days; (d) first paying subscribers. Targets (what counts as "daily", how many subscribers, by when) are TBD.
13. **Not yet decided:** web version; which features are free and which are premium; subscription price; lifetime option.
14. **Scope change (2026-11-13):** the founder moved energy modes (F-08), the basic life score (F-09) and the fail-day next step (F-10), the old milestone M4, from the first release to v2, the second build. v1 is F-01 to F-07, F-11 and F-14. The held features are listed in `docs/V2-FEATURES.md`. This changes the approved first-release scope in Feature-Specification.md, PRD.md and System-Architecture.md; those files were updated and need the founder's re-approval of the changed parts.

## Known issues
1. **Life line score mismatch:** the proposed score formula gives 58 with the sample area scores, while the dashboard sample shows 62. To be resolved when the formula is approved.
2. **Contradictory sample insight:** "Financial Freedom: no focus time in 12 days" conflicts with the sample project "Build Life System app", which serves a Financial Freedom goal and has recent focus time. The prototype computes insights from data, so it does not show this contradiction.
3. **Open decisions from the master brief:**
   - life stage names and score thresholds
   - the soft limit on active life areas (3 to 8)
   - which external calendars to sync
   - minimum data before an insight appears
   - the placeholder habit name "Master skill"
4. **Workflow order:** design and prototype work happened before product documentation, technology selection and architecture. Later phases may require design changes.

## Next actions
1. **User:** answer the Phase 01 question on the business model.
2. **Claude:** ask the remaining Phase 01 questions, one at a time: competitors and unique value proposition, then success criteria.
3. **Claude:** write the Initial Product Concept and Requirements Summary from the Blueprint, the master brief and the answers.
4. **User:** approve the summary in plain words, or request changes.

## Latest document versions
| Document | Version | Status |
|---|---|---|
| Project-Status.md | 0.1 | IN PROGRESS |
| Life System Blueprint (blueprint.html, PDF) | Draft 01 | Input to Phase 01, not approved |
| Life System design master brief | 1 | Input to Phases 01, 02 and 05, not approved |
| Concept and Requirements Summary | 0.2 | APPROVED 0.1; platform section revised 2026-11-11 |
| PRD.md | 0.4 | APPROVED (2026-11-11) |
| Feature-Specification.md | 0.3 | APPROVED (2026-11-11) |
| User-Flows.md | 0.2 | APPROVED (2026-11-11) |
| Technology-Stack.md | 0.5 | APPROVED (2026-11-11) |
| System-Architecture.md | 0.1 | APPROVED (2026-11-11) |
| Design-System.md | n/a | NOT STARTED (design system exists on claude.ai) |
