# Domain Model

## User

Fields:

* id
* email
* firstName (optional)
* lastName (optional)
* createdAt
* roles: set of `ROLE_USER` / `ROLE_ADMIN` / `ROLE_TRAINER` / `ROLE_SUPER_ADMIN` — every user has `ROLE_USER`; `ROLE_TRAINER` is grantable via `ROLE_SUPER_ADMIN`-only endpoints, `ROLE_ADMIN`/`ROLE_SUPER_ADMIN` are SQL-only (see `docs/personal_trainer/03-backend-terv.md` §RoleManagementService)

## Food

Fields:

* id
* name
* caloriesPer100g
* proteinPer100g
* carbsPer100g (optional field)
* fatPer100g (optional field)
* originSourceId (optional) / originTrainerId (optional) — set only on a trainer-assigned copy (see `docs/personal_trainer/02-domain-es-migraciok.md`, "Változás 3"); drives the mobile "Edzőtől" badge

## Recipe

Fields:

* id
* name
* description
* originSourceId (optional) / originTrainerId (optional) — same provenance pair as Food

Relationships:

Recipe
-> many RecipeIngredients

## RecipeIngredient

Fields:

* recipeId
* foodId
* quantityInGrams

## Meal

Fields:

* id
* dateTime
* mealType

Meal Types:

* Breakfast
* Lunch
* Dinner
* Snack

## MealEntry

Fields:

* mealId
* foodId
* quantityInGrams

## Exercise

Fields:

* id
* name
* originSourceId (optional) / originTrainerId (optional) — same provenance pair as Food

## WorkoutTemplate

Fields:

* id
* name
* originSourceId (optional) / originTrainerId (optional) — same provenance pair as Food

## WorkoutTemplateExercise

Fields:

* workoutTemplateId
* exerciseId

## WorkoutSession

Fields:

* id
* startedAt (optional) — null for a trainer-scheduled session that hasn't been started yet; a row is always either started or scheduled (see `WorkoutSchedule`)
* finishedAt
* scheduledFor (optional) — calendar day the trainer scheduled this session for (docs/personal_trainer/09-utemezett-edzesek-domain-backend.md)
* scheduledTime (optional) — wall-clock time-of-day copied from the originating `WorkoutSchedule`; display/ordering only
* scheduleId (optional) — the originating `WorkoutSchedule`, if this session was materialized from one

## ExerciseSet

Fields:

* workoutSessionId
* exerciseId
* reps
* weight

## WeightEntry

Fields:

* id
* date
* weight

## TrainerClient

A trainer-client relationship — and, while `status = PENDING`, the invite itself (docs/personal_trainer/02-domain-es-migraciok.md, "Változás 2"). Not delta-synced.

Fields:

* id
* trainerId
* clientId
* status: `PENDING` / `ACTIVE` / `DECLINED` / `REVOKED` / `EXPIRED`
* createdAt
* expiresAt — 24h invite validity window
* respondedAt (optional)
* revokedAt (optional)
* revokedBy (optional) — plain id, not a mapped relation

## ContentAssignment

The fact log of what a trainer assigned to a client — distinct from a copy's own `originSourceId`/`originTrainerId`, which record provenance rather than the assignment event (docs/personal_trainer/02-domain-es-migraciok.md, "Változás 3").

Fields:

* id
* trainerId
* clientId
* contentType: `TEMPLATE` / `RECIPE`
* sourceId — the trainer's original entity id (not an FK: may be soft-deleted later)
* copiedId — the client's new copy
* assignedAt

## WorkoutSchedule

A trainer-defined recurring or one-off schedule that materializes into a batch of unscheduled-start `WorkoutSession` rows for the client (docs/personal_trainer/09-utemezett-edzesek-domain-backend.md). Session rows are the source of truth for individual occurrences — this row records the series itself, so it can be cancelled as a unit.

Fields:

* id
* trainerId
* clientId
* sourceTemplateId — the trainer's original template id (not an FK: may be soft-deleted later)
* clientTemplateId — the client's own copy, which sessions are materialized from
* recurrence: `ONCE` / `DAILY` / `WEEKLY`
* daysOfWeek (optional) — `WEEKLY` only, CSV of `DayOfWeek` names
* timeOfDay (optional) — inherited by every occurrence
* startDate
* endDate — `= startDate` for `ONCE`; capped at `startDate + 3 months`
* createdAt
* cancelledAt (optional)

## RoleAuditLog

Append-only record of a `ROLE_TRAINER` grant/revoke via the `ROLE_SUPER_ADMIN` API (docs/personal_trainer/02-domain-es-migraciok.md, "Változás 4"). `ROLE_ADMIN`/`ROLE_SUPER_ADMIN` changes never go through this path — SQL-only, unaudited.

Fields:

* id
* actorId — the super admin who made the change
* targetUserId
* role
* action: `GRANT` / `REVOKE`
* createdAt
