# PRD.md
Project: Orbito | Version: 0.4 | Date: 2026-11-11
Status: NEEDS REVIEW

Revision notes (2026-11-11): version 0.2 (approved) moved accounts, server and sync into the first release. Version 0.3: the founder decided the first release is for Windows and Android only. Apple versions (Mac, iPhone, iPad) come later, after all features are confirmed. Version 0.4: the initial release is a closed test with the founder's friends on free infrastructure ($0).

## 1. Product overview
Orbito is a personal life operating system. It lets one person plan their life, record what they do each day, see an honest measure of where they stand, and learn from their own data why things go well or badly. Planning and tracking are connected by one chain: Life Area, Goal, Project, Task and Focus Session.

## 2. Problem statement
People who want to improve their lives use separate tools for tasks, calendar, habits, sleep and notes. These tools do not connect, so no single tool shows how daily actions relate to long-term goals or why progress has stalled. This statement comes from the founder's blueprint and a light review of comparison articles. It has not been tested with users.

## 3. Product objectives
1. The founder uses the app every day for 90 days (the definition of "every day" is TBD - pending Phase 02 review).
2. The app reaches its first paying subscribers (number and date TBD - pending Phase 02 review).
3. The app measures the user's real position in each area of life and shows what to do next, including after a failed day.

## 4. Target audience
Primary expected customers are people with ADHD, as stated by the founder. Market size and willingness to pay are not verified. The product is a general life app with ADHD-friendly design. It is not an ADHD-only product and makes no medical claims. The first user is the founder.

## 5. User personas
TBD - pending user research. Persona 1 is the founder, who uses the app personally before any sales. Further personas will be written only from real user feedback, not assumed.

## 6. Core features (summary)
P0 (first release): tasks, habits, focus timer, sleep log, life areas with goals and projects, customisable Today dashboard, Quick Launcher, energy modes, basic life score, fail-day next step, offline use on the device, and accounts with a server and sync across devices.
P1 (before selling): insights with 14-day tests, notes, calendar sync, trial and subscription billing, analytics, free and premium split.
P2 (future): web version, Apple Watch, AI helpers, more integrations, sharing and any feature added after beta.
Details are in Feature-Specification.md.

## 7. Functional requirements
The functional requirements are the features in Feature-Specification.md. Each P0 feature must meet its acceptance criteria before the first release.

## 8. Non-functional requirements (performance, reliability, usability)
- Usability: ADHD-friendly design. Screens are not crowded. The user chooses which dashboard sections to show. One-tap logging for common actions. No streak pressure and no shaming wording. A low-energy mode shows only what matters now.
- Reliability: the P0 features work without an internet connection, and changes made offline sync when the connection returns. No user data is lost if the app closes unexpectedly.
- Industry readiness (proposed, thresholds TBD - pending Phase 04): secure sign-in, encrypted data in transit and on the server, backups and recovery, error monitoring, a privacy policy, and testing on every target platform before release.
- Performance: TBD - pending Phase 03 (targets will be set once the technology is chosen).
- Extensibility: the product is built in separate parts so new features can be added after beta without breaking existing ones. This is a standing requirement from the founder.

## 9. Platform requirements
First release platforms: Windows and Android. Later platforms: Mac, iPhone and iPad, built after all features are confirmed. Apple users remain the main long-term market. The web version is not decided (listed as P2). The founder owns Windows and Android devices only. Apple development normally requires a Mac and a $99 per year developer membership; this is planned for the later Apple release.

## 10. Business requirements / business model
Freemium subscription. Personal use first. The initial release is a closed test with the founder's friends, launched at $0 on free plans of the server services and without paid store accounts. Sales begin only when the app is fully functional across platforms, and paid server plans are expected before real customers use it. Every new user receives a one-month trial with all premium features. After the trial, premium features are switched off and the free tier remains. The founder will test every existing feature before deciding which are free and which are premium. Price and any lifetime option: TBD - pending founder decision.

## 11. Security and privacy requirements
- User data belongs to the user. Data is not sold and not used for advertising.
- Data about habits, sleep and mood can be health-related and sensitive. The legal rules for each target country must be verified before launch. TBD - pending Phase 04 and Phase 11.
- The app never claims to diagnose or treat any condition.
- Insights are labelled Fact, Correlation, Hypothesis or Recommendation. A correlation is never presented as a proven cause.
- Because accounts and a server are in the first release, personal data is stored on a server from day one. The privacy policy, account deletion and data export are first-release requirements.
- Authentication and storage design: TBD - pending Phase 04.

## 12. Technical constraints
- One codebase across Windows, Android, Mac, iPhone and iPad is desired, so Apple versions can be added later without a rebuild. Technology: Flutter is proposed in Technology-Stack.md, pending approval.
- The founder has no Apple device, so Apple versions cannot be built or tested in the first release.
- A server, database and sign-in service are needed from the first release. Provider and monthly cost: TBD - pending Phase 03.
- The founder is a non-technical founder building with AI-assisted development.

## 13. Competitors and unique value proposition
Competitors named by the founder: Notion, Todoist, TickTick, Notion Calendar, Sunsama, Akiflow, Morgen. Others found: Tiimo, Inflow, Structured, Finch, Xenith, Discy, Evident, Exist, Gyroscope, Bearable, LifeWheel.
Working hypothesis, not yet verified: no single app found combines life areas, goals, projects, tasks, daily tracking and cause-finding insights with an ADHD-friendly design across Mac, iPhone, iPad, Windows and Android. Xenith and Discy are the closest and need a closer look.

## 14. Success criteria
1. The app works for the founder every day for 90 days.
2. First paying subscribers.
Numbers and dates: TBD - pending founder decision.

## 15. Open questions
1. Which features are free and which are premium (after founder testing).
2. Subscription price and any lifetime option.
3. Whether the web version is built and when.
4. Which calendars to sync.
5. Life score formula and stage names.
6. Success targets (definition of "every day", number of subscribers, date).
7. Backend provider and monthly running cost (Phase 03).
8. Hardware plan for the later Apple release (buy a Mac, or another way to test Apple apps).
9. Whether the trial and subscription billing (F-16) also move into the first release. Currently P1.
