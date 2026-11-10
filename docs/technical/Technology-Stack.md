# Technology-Stack.md
Project: Orbito | Version: 0.5 | Date: 2026-11-11
Status: APPROVED

Version 0.5: the initial release is a closed test with the founder's friends at $0 cost, using free plans (see sections 3 and 4).

Revision note (2026-11-11): the founder moved accounts, server and sync across devices into the first release (P0). Version 0.2 replaces the approved 0.1 and needs re-approval.

Verification note: facts below were checked by web search on 2026-11-11. Sources disagree on some current version numbers, so every version, price and limit must be confirmed on the official site before purchase or build. Items marked "not verified" were not confirmed.

## 1. Requirements that drive the choice
- First release for Windows and Android only. One codebase that can later also produce Mac, iPhone and iPad versions (Apple is the main long-term market).
- First release (P0) is for personal use and works offline first, with accounts, a server and sync across devices included (changed on 2026-11-11).
- Later (P1): calendar sync, insights, notes and, unless the founder moves it up, trial and subscription billing.
- The founder is non-technical and builds with AI-assisted development; the founder owns Windows and Android devices only.
- Freemium subscription business model; the product must stay open to new features after beta.
- Sensitive personal data (habits, sleep, mood) requires careful privacy handling.

## 2. Decisions (repeat per layer: frontend, backend, database, authentication, cloud/hosting, APIs, state management, offline/local storage, deployment, AI dev tools)

### Frontend (app framework)
- Options compared:
| Option | Advantages | Disadvantages | Cost | Limits |
|---|---|---|---|---|
| Flutter (Dart) | One codebase for iOS, Android, macOS, Windows, Linux and web. Large adoption (about 30% of new free iOS apps per one 2026 report). Founder's suggestion. | Dart is a niche language. Desktop is less mature than mobile; one source says the new renderer is not yet on desktop, another says it is the default (conflict, not verified). Critics call desktop "mostly stagnant" (community claim). | Free; no licence fee found | Version numbers conflict across sources (3.38, 3.44, 3.47); check flutter.dev |
| React Native | Largest hiring pool; JavaScript or TypeScript. | Desktop is not a core focus per one source, so Mac and Windows need extra work. | Free | Desktop support weaker |
| Kotlin Multiplatform with Compose | Lists macOS, Windows, iOS and Android. | Highest learning curve; fewer examples. | Free | Smaller ecosystem |
| Separate native apps (Swift and Kotlin) | Best fit for each platform. | Several codebases; far too much work for one founder. | Free tools | Needs a Mac for Apple apps |
- Chosen option: Flutter (proposed).
- Reason: it is the only option reviewed that covers all five target platforms from one codebase with desktop listed as supported, so Apple versions can be added later without a rebuild. The main risk is desktop maturity. For the first release this means Windows, which must be tested early in Phase 06. If Windows support proves inadequate, the fallback is to be decided with the founder.

### Offline and local storage
- Options compared:
| Option | Advantages | Disadvantages | Cost | Limits |
|---|---|---|---|---|
| SQLite through the Drift library | Standard database on every device; works offline; reads fast; later sync can be added. | Sync must be added in P1. | Free | None found |
| Simple key-value storage | Easy. | Poor for linked data (areas, goals, projects, tasks). | Free | Not suitable |
- Chosen option: SQLite through Drift (proposed).
- Reason: P0 needs linked data that works offline. The recommended pattern for later sync is UUID identifiers, a sync queue written in the same step as each change, soft deletes, and server timestamps instead of device clocks. Design these in from the start so P1 sync does not need a rebuild.

### Backend, database, sign-in and hosting (needed for the first release)
- Options compared (prices from articles and vendor pages read on 2026-11-11; confirm on each vendor's own site before paying):
| Option | Advantages | Disadvantages | Cost | Limits |
|---|---|---|---|---|
| Supabase (hosted PostgreSQL with sign-in) | Standard relational database that fits linked data (areas, goals, projects, tasks). Sign-in and hosting included. The data can be moved elsewhere later. | Free plan pauses after about a week of inactivity and has no backups, so it is not suitable for real user data. | Free for development. Pro: $25 per month per organization plus usage. | Free: 500 MB database, 50,000 monthly users, 2 projects. Pro: 8 GB database, 100,000 monthly users, daily backups kept 7 days. |
| Firebase (Google) | Mature; no server to run. | Document database, so linked data needs manual mapping. Pay-as-you-go with no hard spending cap, so a bug can create a large bill. Billed per document read. | Free Spark plan stops at the limit; the Blaze plan is pay-as-you-go. Example from one article: about $9 per month at 5,000 daily users. | Not verified in detail |
| Own server (Node.js with PostgreSQL) | Full control. | The founder must run, secure, update and back up the server. | Server cost, not verified | Highest maintenance |
- Chosen option: Supabase with PostgreSQL, including its sign-in service (proposed).
- Reason: relational data fits this app's structure; costs are predictable; hosting is managed, so the founder does not run servers; and the data is not locked in. Firebase's missing spending cap is a real risk for a solo founder.

### Sync engine (needed for the first release)
- Options compared:
| Option | Advantages | Disadvantages | Cost | Limits |
|---|---|---|---|---|
| PowerSync | A ready-made sync engine; keeps a local SQLite database in step with PostgreSQL; has a Flutter SDK; open source and can be self-hosted. | Its page does not state Supabase support directly; it states PostgreSQL support. Adds a second paid service. | Free plan; Pro from $49 per month; Team from $599 per month. | Free: 2 GB synced per month, 500 MB hosted, 50 simultaneous devices, deactivated after inactivity (the page gives one week and two weeks in different places). Pro: 30 GB synced, 10 GB hosted, 1,000 devices. |
| Custom sync built with AI help (queue plus server timestamps) | No extra service cost. | Sync is hard to get right; bugs can lose or duplicate data, which is serious for an industry-ready release. | $0 extra | Highest risk |
- Chosen option: PowerSync with Supabase (proposed).
- Reason: sync is the most error-prone part of the system. Using a proven engine reduces the risk of data loss. The compatibility of PowerSync with Supabase must be proven in a small test early in Phase 06.
- Estimated running cost at launch: about $25 plus $49, or about $74 per month, before usage overages and taxes. Development and beta with a few users can use the free plans.

### Authentication
- Supabase's sign-in service (proposed). Free plan: 50,000 monthly active users; Pro: 100,000. Sign-in methods: TBD - pending Phase 04. Apple may require "Sign in with Apple" if other social sign-in options are offered; to be verified in Phase 04.

### Cloud/hosting
- Managed hosting by Supabase and PowerSync Cloud, so the founder does not run servers (proposed).

### APIs
- P0: none. P1: calendar services (Google, Outlook, iCloud: TBD - pending founder decision). AI helpers are P2.

### State management
- Choice of the Flutter state library (for example Riverpod) is an implementation choice and will be made in Phase 06 or 07. TBD - pending Phase 06.

### Deployment
- Options and verified costs:
| Store | Fee | Commission |
|---|---|---|
| Apple App Store (iPhone, iPad, Mac) | $99 per year | 30% standard; 15% under the Small Business Program for eligible developers; subscriptions typically 15% after a subscriber's first year |
| Google Play | $25 one-time | 15% on the first $1M per year; 15% for subscriptions |
| Microsoft Store | Free for individual developers (Microsoft announcement, September 2025; confirm before registering) | Not stated; apps may use their own in-app commerce and keep 100% of revenue (non-game apps, per the same announcement) |
- First release: Google Play and the Microsoft Store (or direct download for Windows, not verified). The Apple App Store is for the later Apple release.
- Publishing to the Apple App Store requires the paid membership. A free Apple account only allows testing on your own devices, with builds that expire after 7 days. Apple's rules and prices change; confirm on developer.apple.com before paying.
- Chosen option: Google Play and Microsoft Store for the first release; Apple App Store later.

### Payments and subscriptions (P1)
- RevenueCat is a common subscription service. A January 2026 staff reply said it does not support Windows and Linux for Flutter, and offered web billing (RevenueCat Web Billing, Stripe or Paddle) as the workaround. macOS support was not confirmed. Apple and Google stores require their own in-app purchase systems for subscriptions sold inside the apps; this must be verified in Phase 04.
- Chosen option: TBD - pending P1 and Phase 04.

### AI dev tools
- Claude Code for building and Claude for planning and review (as in this project). Cost: depends on the founder's plan, not verified.

## 3. Estimated costs (verify current pricing)
| Item | Cost | Status |
|---|---|---|
| Apple Developer Program | $99 per year | Verified from two sources; not needed until the Apple release |
| Google Play account | $25 one-time | Verified |
| Flutter and Drift | Free | No licence fee found |
| Supabase Pro | $25 per month plus usage | From an article dated 2026; confirm on supabase.com |
| PowerSync Pro | From $49 per month | From PowerSync's pricing page; confirm before paying |
| Development and beta | $0 on free plans | Free Supabase has no backups and pauses when idle |
| Cloud builds for Apple apps (Codemagic) | 500 free Mac minutes per month, then $0.095 per minute | From Codemagic's pricing page |
| Mac computer or other way to test Apple apps | Not verified | Deferred to the Apple release |
| Microsoft Store account | Free for individuals | From Microsoft's announcement; confirm before registering |

### Initial release at $0 (closed test with friends)
| Item | Cost | Note |
|---|---|---|
| Supabase free plan | $0 | 500 MB database, 50,000 monthly users, 2 projects. Pauses after about a week of inactivity and must be reactivated by hand. No backups. |
| PowerSync free plan | $0 | 2 GB synced per month, 500 MB hosted, 50 simultaneous devices. Deactivates after inactivity (one week or two, the page conflicts). |
| Flutter, Drift | $0 | |
| Distribution to friends | $0 | Share the Windows installer and the Android install file directly. This is common practice but was not verified in this research. Google Play ($25 one-time) and the Microsoft Store (free for individuals) are optional for the test. |

Total: $0, with the limits above. Paid plans (about $74 per month for Supabase Pro and PowerSync Pro) are expected before public sales.

## 4. Risks and limitations
1. **Apple hardware (deferred).** The founder has no Mac or iPhone, so Apple versions wait until after all features are confirmed. At that point a plan is needed: a cloud build service (Codemagic offers 500 free Mac build minutes per month) compiles apps but does not let you see or touch them, so testing needs a real Apple device or another method that was not researched. Publishing needs the $99 per year membership.
2. **Flutter desktop maturity.** Sources conflict on how mature desktop support is. A test build of the real app on Windows is the first task in Phase 06.
3. **Language.** Dart is a niche language. The founder does not need to write code, but AI coding quality for Dart was not verified.
4. **Running two paid backend services** (about $74 per month at launch) before there are paying users.
5. **Subscription billing across platforms** is more complex than on mobile alone (see Payments).
6. **Free-plan limits for the closed test.** The free Supabase plan has no backups, so a mistake or outage can lose friends' data. The apps keep a copy of each user's data on their own device and offer data export, which reduces the risk. Idle projects pause and need manual reactivation. Friends should be told this is a test.
7. **Sensitive data** may carry legal duties in some countries. To be verified in Phase 04.

## 5. Approval record (date, approved by)
Approved by the founder on 2026-11-11 (version 0.5, including the $0 initial release and Windows and Android first). Choices: Flutter, SQLite with Drift, Supabase (PostgreSQL and sign-in), PowerSync.
