# 80 – Progress Photos and Body Measurements

Status: built (2026-10-02, branch `feature/progress-photos-measurements`) — P1–P8 done; emulator walk and a Docker `mvnw verify` still owed (step log in §12)
Scope: roadmap item #10 (`docs/05-improvement-roadmap.md`) — backend + mobile
Depends on: `docs/22-profile-picture-plan.md` (`ImageReencoder`, multipart limits, the
online-only thumbnail cache), `docs/16-delta-sync-rollout.md` (synced-entity recipe),
`docs/76-smarter-weight-trend-plan.md` (the Weight screen this hangs off)

## 1. What we're building

1. **Body measurements** — waist, chest, hips, arm, thigh in cm. Each is logged with a date,
   works offline, syncs like a weight entry, and has a history list plus a line chart per site.
2. **Progress photos** — a dated photo (optionally tagged front / side / back) in a timeline,
   with a **side-by-side compare** of any two photos.
3. Both live behind a **Body** entry on the Weight screen, so the one place a user already
   goes to record how their body changed holds all three: weight, measurements, photos.
4. Everything is private to the owner. Nothing here is visible to a trainer (§2.6).

## 2. Key design decisions

### 2.1 Measurements are a synced entity, photos are not

Measurements are small numbers that must be loggable in a gym changing room with no signal —
exactly the weight-entry shape, so they take the full offline-first route
(`SyncableEntity`, outbox, delta feed). Photos are megabytes; routing them through the outbox
would mean persisting blobs in Drift and a retry story for large multipart bodies. The recipe
and avatar images already settled this: **online-only, server is the source of truth, thumbnails
cached on disk with an ETag** (`recipe_image_repository.dart`). Photos follow that. The cost —
the timeline is empty with no connection until thumbnails are cached — is accepted (§5).

### 2.2 One row per (date, site), not one wide row per day

`body_measurements(entry_date, site, value_cm)` rather than a row with five nullable columns.
Charts and history are per site; a user who only tracks waist never carries four empty columns;
adding a site later is an enum value, not a migration. Rejected: wide row — a partial update
("I measured only my arm today") would need merge semantics in sync, which the entity-per-fact
model gets for free.

### 2.3 A fixed site enum, no left/right

`WAIST, CHEST, HIPS, ARM, THIGH`. Left/right split doubles the UI for a distinction most users do
not track; users who care can log the larger side consistently. Stored as a `VARCHAR` with a
`CHECK`, same as other enums in the schema, so a new site is additive.

### 2.4 Photos are server-resized, EXIF stripped, via the existing pipeline

Upload goes through `ImageReencoder` (decode = validation, re-encode strips EXIF/GPS). A body
photo carries location metadata the user never meant to publish, so stripping is not optional.
Main image: long side 1600 px (progress photos are looked at full-screen and compared; the 1024
px used for recipes is too soft), thumbnail 256 px square. This uses `boundedJpeg`, not
`resizedJpeg`, so a small source is not upscaled.

### 2.5 Photos are bytes in Postgres, like avatars and recipe images

Same `bytea`, deliberately not `@Lob`, in a separate table from the metadata so a list query
never drags image bytes (`UserAvatar#image` explains the oid trap). No object storage: this
would be a new infrastructure dependency for a feature the existing pattern already serves, and
CLAUDE.md asks for justification before new moving parts. Revisit if photo volume becomes a
storage problem (§5).

### 2.6 Trainer visibility is a non-goal, and stays one

Body photos are the most sensitive data in the app. There is no trainer-facing endpoint and the
trainer ownership checks must not be extended to these tables. Sharing with a trainer would be a
separate, explicit-consent feature with its own plan.

### 2.7 Compare is a client-side view over two timeline photos

No server compare endpoint: the client has both full images by id. The compare screen picks a
"before" and an "after", defaults to the oldest and newest, and shows them in two equal panes
with a date caption each. A synchronised pinch-zoom is nice-to-have and a non-goal for v1.

## 3. Data model

```
body_measurements              (V78)
  id, user_id, entry_date, site, value_cm,
  created_at, updated_at, deleted_at            -- SyncableEntity columns (no client_id: weight has none)
progress_photos                (V79)
  id, user_id, taken_on (date), pose (FRONT|SIDE|BACK|OTHER), note?, created_at
progress_photo_images          (V79)
  photo_id (unique FK, ON DELETE CASCADE), image bytea, thumbnail bytea, content_type, updated_at
```

Migration numbers are the next free pair after `V77__trainer_request.sql`; confirm at step time.

## 4. API

| Endpoint | Purpose |
|---|---|
| `POST/DELETE /api/v1/measurements`, `GET /api/v1/measurements` (+ `?updatedSince=` delta) | create/delete (no edit — delete and re-log, same as weight) + delta feed |
| `POST /api/v1/progress-photos` (multipart: `file`, `takenOn`, `pose`) | create, returns metadata |
| `GET /api/v1/progress-photos` | metadata list, newest first |
| `GET /api/v1/progress-photos/{id}/image` and `/thumbnail` | bytes, ETag + `If-None-Match` |
| `PATCH /api/v1/progress-photos/{id}` | change `takenOn` / `pose` / `note` |
| `DELETE /api/v1/progress-photos/{id}` | hard delete (§6) |

## 5. Non-goals (deferred)

- Left/right measurement split; custom sites; body-fat estimation.
- Offline photo capture/queue and an offline timeline beyond already-cached thumbnails.
- Trainer visibility or sharing (§2.6); exporting a before/after as an image.
- Synchronised zoom in compare; pose-overlay guide on the camera.
- Pro gating — free for all in v1; storage growth is the thing to watch before deciding.
- HealthKit / Health Connect measurement write-back.
- A per-user photo cap. Add one if storage becomes a concern; not guessed up front.

## 6. Edge cases

- Deleting a photo is a **hard delete** of both rows (nothing to sync, and soft-deleted body
  photos lingering in a table is the wrong default). Account deletion cascades via the FKs.
- Two measurements for the same site on the same date are allowed (like weight; newest by
  `updated_at` is shown as the day's value in the chart).
- Value bounds: `value_cm` in (0, 300]; validated on the DTO and by a DB `CHECK`.
- A future `takenOn` is rejected; a very old one is fine (people add photos retroactively).
- Non-image / oversized upload → `InvalidImageException` (existing 400 handling); >10 MB is cut by
  the multipart limit.

## 7. Order of work

Milestones are demoable slices. **M1 is the smallest thing worth using.**

### M1 — Measurements

| Step | Surface | What | Verify |
|---|---|---|---|
| P1 | Backend | V78 migration, entity, repo, service, controller, delta feed, DTO validation | `mvn test` — controller + service tests, ownership, delta, validation |
| P2 | Mobile data | Drift table, repository + outbox, pull-sync, domain model | repository + sync tests |
| P3 | Mobile UI | Body entry on Weight screen; measurements list, add sheet, per-site chart | `flutter test`, emulator walk |

### M2 — Photos

| Step | Surface | What | Verify |
|---|---|---|---|
| P4 | Backend | V79 migration, entities, upload/list/image/thumbnail/patch/delete | `mvn test` — upload re-encode strips EXIF, ownership, ETag/304, cascade |
| P5 | Mobile data | repository + thumbnail/full cache, upload controller | unit tests with a fake Dio |
| P6 | Mobile UI | timeline grid, add from camera/gallery, detail with delete/edit | `flutter test`, emulator walk |
| P7 | Mobile UI | compare screen | widget test, emulator walk |

### M3 — Close

| Step | Surface | What |
|---|---|---|
| P8 | Docs | status lines, roadmap #10 DONE, `REMAINING-WORK.md` §1.3 removed, Postman collection, README index |

Each step also carries its own HU/EN strings (`localization` skill) and leaves `main` working.

## 8. Test plan

- Backend: controller tests per endpoint (happy path, 400 validation, 404 for another user's id),
  delta-feed test, image test with a JPEG that carries EXIF asserting the stored bytes do not,
  ETag round trip. Repository-level queries tested against Testcontainers as elsewhere.
- Mobile: repository and sync tests mirroring `weight`; widget tests for the add sheet and the
  compare screen's default selection.
- Manual (emulator): the offline add-measurement → reconnect path; photo upload from gallery.

## 9. Suggested PR split

One PR per milestone is the natural size (M1 ≈ P1–P3, M2 ≈ P4–P7, M3 folded into M2's PR). The
branch carries one commit per step so a reviewer can read it step by step.

## 10. Silent-failure risks

- **EXIF/GPS leaking** if a code path stores the raw upload instead of the re-encoded bytes —
  covered by the EXIF test; reviewers should grep for `getBytes()` on the upload.
- **Another user's photo served** if a lookup uses `findById` instead of `findByIdAndUserId` —
  every photo and measurement query must be scoped; test with two users.
- **Measurement `updated_at` not bumped** on update, so the delta feed never delivers the edit —
  the same trap `docs/15-delta-sync.md` warns about; test the feed after an update.
- **Stale cached thumbnail** after a photo is edited: cache key includes `updated_at`/ETag.
- **Image bytes in list queries**: the metadata table is separate on purpose; do not add the
  image relation as an eager association.

## 11. After implementation

Update: `05-improvement-roadmap.md` #10 → DONE, `REMAINING-WORK.md` §1.3 removed, `docs/README.md`
plan table, Postman collection. Record deviations from this plan in a §12 "As built" section.

## 12. As built / step log

- **P1 (backend measurements) — done.** `com.lifey.bodymeasurement`, `V78__body_measurements.sql`,
  `/api/v1/measurements`. Controller + service tests pass (`BodyMeasurement*Test`). Docker was not
  available in the session, so the Flyway-vs-entity `validate` run (`mvnw verify`) is still owed.
- **P2 (mobile data, measurements) — done.** `mobile/lib/features/measurements/{domain,data,application}`,
  Drift table `body_measurements` (schema v45), `entitySyncConfigs` + `allEntityTableNames`, pull
  (full + delta + tombstones, pending-op guard) in `PullEngine`. Tests: repository + pull engine.
  `flutter analyze` clean; the only failing suite tests are the known Windows chat-attachment ones.
- **P3 (mobile UI, measurements) — done.** `BodyMeasurementsScreen` at `/body-measurements`, reached from a
  ruler icon in the Weight screen header: site chips (wrapping — five do not fit one row at 411 dp),
  latest value + change + line chart, swipe-to-delete history, add sheet (comma decimals, 1–300 cm).
  HU/EN strings added; `check_arb_sync.sh` reports nothing for the new keys (its only output is the
  pre-existing `statUnitWorkouts` false positive). Widget + unit tests pass. **Emulator walk still owed.**
  The header button currently opens measurements directly; P6 decides how photos join it.
- **P4 (backend photos) — done.** `com.lifey.progressphoto`, `V79__progress_photos.sql` (metadata and bytes in
  two tables), `/api/v1/progress-photos` (list, multipart create, PATCH metadata, image + thumbnail with
  ETag/304, hard delete). Main image bounded to 1600 px (never upscaled), thumbnail 256 px square, EXIF
  stripped (test splices an APP1 "Exif" segment into a JPEG and asserts it is gone). **Deviation:** a bad
  `pose`/date form parameter returned 500 in `GlobalExceptionHandler`, so P4 adds a global
  `MethodArgumentTypeMismatchException` → 400 handler. 289 non-Docker backend tests pass; the two
  Testcontainers integration tests and the Flyway-vs-entity `validate` need Docker and are still owed.
- **P5 (mobile data, photos) — done.** `mobile/lib/features/progress_photos/{domain,data,application}`:
  `ProgressPhotoRepository` (REST + ETag disk cache per id and variant, injectable cache root for tests),
  `ProgressPhotoController` (async list, optimistic-free: inserts the server's response in date order),
  thumbnail/full image providers. Logout now also clears the photo cache and invalidates the controller
  (`AuthController`). 14 tests (fake Dio adapter, temp cache dir).
- **P6 (mobile UI, photos) — done.** The Weight header's entry now opens a **Body** screen (`/body`,
  `features/body`) with a Measurements | Photos switch; each tab brings its own floating action. The P3
  `BodyMeasurementsScreen` became `BodyMeasurementsTab` (no Scaffold). Photos tab: 3-column timeline grid
  (thumbnail, date, pose), camera/gallery source sheet -> `image_picker` (1600 px, q90) -> details sheet
  (pose chips, date, note) that uploads on Save and stays open with an error on failure; viewer
  `/progress-photos/:photoId` (pinch-zoom, thumbnail shown while the full image loads, edit, confirm-delete).
  Camera/library permission strings already exist (chat attachments). Tests: widget tests for tab, tile,
  viewer delete flow, details sheet add/edit/failure, Body tab switching. **Emulator walk still owed.**
- **P7 (mobile UI, compare) — done.** `PhotoCompareScreen` at `/progress-photos/compare` (declared before
  `/progress-photos/:photoId` so `compare` is not parsed as an id): oldest vs newest by default, tap a pane
  to re-pick that side from a thumbnail grid, "N days apart" between them; a Compare button appears above
  the timeline from two photos on. HU/EN strings; iOS camera/photo-library usage strings now also name
  progress photos and chat attachments (they only mentioned barcodes and the profile picture).
- **P8 (docs) — done.** Roadmap #10 → DONE, `REMAINING-WORK.md` §1.3 closed (and the two owed checks listed
  under §3 there), `docs/README.md` status, Postman collection (Body Measurements + Progress Photos folders,
  `measurementId` / `progressPhotoId` variables).

### Still owed

1. Emulator walk: Weight → Body → add a measurement (offline, then reconnect), add a photo from the gallery
   and the camera, viewer edit/delete, compare, light theme and Hungarian.
2. ~~`cd backend && ./mvnw -B verify` with Docker running~~ — **done 2026-10-03** (during plan 82): the whole suite, 1159 tests, ran green against Postgres 16, V78 and V79 included.
3. Consider before release: the photo list is unpaged (fine for hundreds, revisit with a cap), and the
   Weight header now has two action buttons — check the title still fits at large text scale.
