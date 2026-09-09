# Lifey documentation

Index of `docs/`. Every non-trivial feature starts as a numbered plan here, and
the code cites those plans by section — migrations, entity javadoc and Dart
comments all refer back to them.

**Numbering.** Root docs and most topic folders share one global sequence
(currently up to `71`, in `landing_page/`). Take the next free number, never reuse a
gap, and keep the `NN-<kebab-topic>-plan.md` shape. Two exceptions exist for
historical reasons: `web/` runs its own `01–09` series, and a few early numbers
are duplicated at the root (`05`, `06`, `15`, `16`).

**Language.** New plans are written in English. Many existing docs — the
`cardio/`, `chat/`, `watch/`, `music/`, `web/` and `personal_trainer/` folders
in particular — are Hungarian; keep editing those in the language they are
already written in rather than making a single document bilingual.

The `feature-plan-doc` skill (`.claude/skills/feature-plan-doc/`) carries the
full format: header block, section skeleton, decision ids, and how to size
iterations.

## Start here

| Doc | What it covers |
|---|---|
| [01-product-vision.md](01-product-vision.md) | Fitness & Nutrition Tracker — product vision |
| [02-architecture.md](02-architecture.md) | Technical architecture |
| [03-domain-model.md](03-domain-model.md) | Domain model |
| [04-mobile-app.md](04-mobile-app.md) | Mobile application requirements |
| [05-backend-api.md](05-backend-api.md) | Backend API requirements |
| [06-development-rules.md](06-development-rules.md) | Development rules (Java, DTOs, injection, Flyway) |
| [10-offline-frontend.md](10-offline-frontend.md) | Offline-first synchronization architecture — read before touching sync |
| [13-localization-guide.md](13-localization-guide.md) | HU/EN localization reference (see also the `localization` skill) |
| [15-delta-sync.md](15-delta-sync.md) | Delta sync design spike — the reasoning behind the cursor model |
| [16-delta-sync-rollout.md](16-delta-sync-rollout.md) | Delta sync rollout plan, entity by entity |

## Roadmaps

| Doc | What it covers |
|---|---|
| [07-roadmap.md](07-roadmap.md) | Version roadmap (V1, V2, …) |
| [05-improvement-roadmap.md](05-improvement-roadmap.md) | Improvement roadmap — most numbered plans below cite an item here |

## Topic folders

| Folder | What it covers |
|---|---|
| [`cardio/`](cardio) | Non-set-based training (running, bike, hike, games): overview, backend, mobile, GPS, watch, statistics, web, design — has its own README with a reading order |
| [`personal_trainer/`](personal_trainer) | Trainer role: concept, domain, backend, web admin, mobile, scheduling, calendar — has its own README |
| [`web/`](web) | The Next.js web surface: feature inventory, architecture, API integration, design system, screens — has its own README, own `01–09` numbering |
| [`chat/`](chat) | Trainer ↔ client chat (40–44), including the extraction of the chat into its own service (44) |
| [`watch/`](watch) | Apple Watch + Wear OS app (40–50): set logging, standalone sessions, template and session sync |
| [`design/`](design) | Design system prompt, design implementation tasks, workout-tab redesigns |
| [`music/`](music) | In-workout music controls (46–47) |
| [`landing_page/`](landing_page) | Monetization and the public marketing surface (63–71): trainer subscriptions, mobile free/Pro, ads, the landing page, and the design specs for both — has its own README with a reading order |
| [`postman/`](postman) | Postman collection for the API |

## Numbered plans

| # | Doc | Status |
|---|---|---|
| 06 | [Post-workout feedback (RPE + note)](06-post-workout-feedback-plan.md) | |
| 08 | [Authentication module](08-auth-module.md) | |
| 09 | [Settings module](09-settings-module.md) | |
| 11 | [Barcode scanner + OpenFoodFacts](11-v2-pland.md) | |
| 12 | [Language selector (HU/EN)](12-language-plan.md) | |
| 14 | [Pagination / lazy loading](14-pagination-plan.md) | proposed |
| 15 | [Set timestamps & rest time](15-set-rest-time-plan.md) | proposed |
| 16 | [Apple Health integration](16-apple-health-integration-plan.md) | proposed |
| 17 | [Statistics page](17-statistics-page-plan.md) | |
| 18 | [Macros tab (nutrition)](18-macros-tab-plan.md) | |
| 19 | [Password management + transactional email](19-password-email-plan.md) | |
| 20 | [Social login — Google / Apple / Facebook](20-social-login-plan.md) | |
| 21 | [Onboarding "step zero" + user_details](21-onboarding-user-details-plan.md) | |
| 22 | [Profile picture](22-profile-picture-plan.md) | |
| 23 | [AI calorie estimation + recipe generation](23-ai-calorie-estimation-plan.md) | |
| 24 | [iOS widget + Live Activity](24-ios-widget-live-activity-plan.md) | |
| 25 | [Android widget + ongoing notification](25-android-widget-ongoing-notification-plan.md) | |
| 26 | [Android Health Connect integration](26-android-health-connect-integration-plan.md) | implemented |
| 27 | [Faster meal logging (roadmap #5)](27-faster-meal-logging-plan.md) | |
| 28 | [Remaining budget view (roadmap #6)](28-remaining-budget-view-plan.md) | |
| 29 | [Compliance overview (roadmap #12)](29-compliance-overview-plan.md) | |
| 30 | [Push notifications (roadmap #8)](30-push-notifications-plan.md) | |
| 31 | [Session feedback loop (roadmap #13)](31-session-feedback-loop-plan.md) | |
| 32 | [Trainer-set nutrition goals (roadmap #17)](32-trainer-nutrition-goals-plan.md) | |
| 33 | [Weekly trainer report email (roadmap #16)](33-weekly-trainer-report-plan.md) | |
| 34 | [Multi-week program builder (roadmap #14)](34-multi-week-program-plan.md) | |
| 35 | [Bulk assignment (roadmap #15)](35-bulk-assignment-plan.md) | |
| 36 | [SonarQube findings remediation](36-sonarqube-findings-remediation-plan.md) | |
| 37 | [Streaks and weekly recap (roadmap #7)](37-streaks-weekly-recap-plan.md) | |
| 38 | [Personal records (roadmap #3)](38-personal-records-plan.md) | |
| 39 | [Rest timer](39-rest-timer-plan.md) | done |

Plans 40–71 live in the topic folders above.

A blank status means the doc does not state one. When you finish work described
by a plan, set its `Status:` line — a plan that still reads "proposed" after
shipping is worse than no status at all.
