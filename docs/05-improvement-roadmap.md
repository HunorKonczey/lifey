# Improvement Roadmap

Proposed features beyond the current state of the app (post-MVP). Grouped by
area, with a suggested implementation order at the end.

Current state (for context): nutrition with barcode scanning, recipes with
images, workout templates + sessions with HealthKit import, weight, water and
steps tracking, statistics, offline-first sync, trainer module (invites,
clients, assignments, schedules, calendar) on the web admin.

## Client (Mobile)

### Workout Experience

#### 1. Rest Timer

* Start a rest timer automatically after logging a set
* Configurable default duration (per exercise or global setting)
* Local notification when the timer ends (NotificationService already exists)
* Visible countdown in the session screen

#### 2. "Last Time" Data While Logging

* When adding a set, show the previous session's sets for the same exercise
  (weight × reps)
* One-tap "repeat last set" to prefill values
* Biggest quality-of-life gain for logging speed

#### 3. Personal Records (PR)

* Detect new PRs when a set is saved: max weight, max reps at weight,
  estimated 1RM
* Celebrate with the existing success pop-up pattern
* PR history listed on the exercise detail screen

#### 4. Post-Workout Feedback (RPE)

* After finishing a session: difficulty rating (1–10) + optional note
* Stored on the session; visible to the trainer (see Trainer section)

### Nutrition

#### 5. Faster Meal Logging

* Favorites / most frequently logged foods surfaced first
* "Copy yesterday's meal" / copy a whole previous day
* Recent items list in the add-entry sheet

#### 6. Remaining Budget View

* "What's left today" — remaining calories and protein, prominent on the
  dashboard and in the meal logging flow

### Motivation & Retention

#### 7. Streaks and Weekly Recap

* Daily goal streaks (calories, steps, water)
* Weekly recap screen (workouts done, average calories, weight trend)

#### 8. Push Notifications (infrastructure + first use cases)

* Backend push infrastructure (APNs, later FCM) — prerequisite for several
  features below; currently only local notifications exist
* Reminder on the day of a trainer-scheduled workout
* Morning weigh-in reminder (local, opt-in)

#### 9. iOS Widget / Live Activity

* Home screen widget: today's calories, steps
* Live Activity during an active workout session (current exercise, rest
  timer)

### Progress Tracking

#### 10. Progress Photos and Body Measurements

* Photo timeline with side-by-side compare
* Measurements: waist, chest, arms, thighs — history + charts
* Reuse the existing image upload infrastructure (recipe/receipt images)

#### 11. Smarter Weight Trend

* 7-day moving average instead of raw daily points
* Goal weight + estimated date of reaching it on the statistics screen

## Trainer (Web Admin)

#### 12. Compliance Overview

* Client list sortable/flagged by: days since last log, missed scheduled
  workouts, weight not logged
* "Needs attention" section on the trainer dashboard
* All required data already exists — aggregation only

#### 13. Session Feedback Loop

* Trainer sees client RPE + notes per session (depends on #4)
* Trainer can comment on a session; client receives a push (depends on #8)
* Minimal viable communication feature — no full chat needed

#### 14. Multi-Week Program Builder

* Build 4–12 week programs: weekly structure, progression between weeks
* Assigning a program generates the scheduled sessions automatically
* Extends the existing schedule/assignment model

#### 15. Bulk Assignment

* Assign a template or recipe to multiple clients at once
* Extension of the existing AssignmentController

#### 16. Weekly Trainer Report Email

* Automatic weekly summary per client: completed workouts, calorie goal
  adherence, weight change
* Mail module already exists

#### 17. Trainer-Set Nutrition Goals

* Trainer can edit (not just view) a client's nutrition goals
* Client is notified of changes

## Suggested Order

Phase 1 — workout logging quality:

1. "Last time" data (#2)
2. Rest timer (#1)
3. Personal records (#3)

Phase 2 — daily-use speed and retention:

4. Faster meal logging (#5)
5. Remaining budget view (#6)
6. Streaks + weekly recap (#7)

Phase 3 — trainer value:

7. Compliance overview (#12)
8. Push infrastructure (#8) — unblocks #13 and future notifications
9. RPE feedback (#4) + session feedback loop (#13)

Phase 4 — bigger bets:

10. Progress photos + measurements (#10)
11. Multi-week program builder (#14)
12. Widget / Live Activity (#9)

Remaining items (#11, #15, #16, #17) are independent quick-to-medium wins
that can be slotted in wherever convenient.
