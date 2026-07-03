# Profile Picture Plan — Upload in Settings + Google Avatar Import

Let users set a profile picture from the Settings screen (upload from gallery/camera), and — when signing in with Google — automatically save the Google account picture **if the user has no picture yet**. Uploaded pictures always win; the Google picture only fills an empty slot.

Related docs: `09-settings-module.md`, `20-social-login-plan.md`, `21-onboarding-user-details-plan.md`.

---

## Is the Google picture available at login?

**Yes.** The Google ID token that the mobile app already sends to `POST /api/auth/social/google` contains a `picture` claim (a `https://lh3.googleusercontent.com/...` URL) whenever the token was requested with the default `profile` scope — which the `google_sign_in` package uses. No extra Google API call and no extra scope is needed; the backend just has to read one more claim in `GoogleIdTokenVerifier`.

Two important properties of that URL:

- It is **not stable long-term** (Google may rotate it), and hotlinking it from the app would leak the user's Google identity to anyone who sees the URL. → **Never store or serve the URL. Download the bytes once, server-side, and store them like an uploaded picture.**
- The URL returns a small square image by default (`=s96-c` suffix). Requesting a larger variant is done by replacing the size suffix with `=s512-c` before downloading.

---

## Architecture

### Storage — decided: A (Postgres bytea)

| Option | How | Pros / cons |
|---|---|---|
| **A — Postgres `bytea` (recommended)** | One row per user in a dedicated `user_avatars` table, image re-encoded to ≤512×512 JPEG (~30–100 KB) | ✅ No new infrastructure, backed up with the DB, trivially consistent with the ownership model. ❌ DB grows ~0.1 MB/user — negligible at avatar sizes. |
| B — Server filesystem | Files on a volume, path in DB | ❌ Complicates deployment/backup/scaling for zero benefit at this size. |
| C — Object storage (S3/R2/MinIO) | Presigned URLs | ❌ New vendor + credentials for a single small image per user. Right answer only if/when we add general photo features (progress photos, meal photos). |

Option A matches the project rule "do not introduce new frameworks without justification". If progress/meal photos ever land, migrate to C then — the API below doesn't change shape.

### Data model

Flyway `V39__user_avatars.sql` (next after `V38__user_details.sql`):

```sql
CREATE TABLE user_avatars (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
    image        BYTEA NOT NULL,
    content_type VARCHAR(50) NOT NULL,          -- always image/jpeg after re-encode
    source       VARCHAR(20) NOT NULL,          -- UPLOAD | GOOGLE
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Separate table (not a column on `users`) so the bytes are never loaded by the frequent `users` lookups (JWT filter resolves the user on every request).

`source` is what implements the priority rule: `UPLOAD` may overwrite anything; `GOOGLE` may only be written when **no row exists**.

### Backend API

New files in the existing `com.lifey.user` feature package (per backend CLAUDE.md layout: entity + repository flat, `service/` pair, controller flat):

```
user/
  UserAvatar.java              (entity, extends BaseEntity)
  UserAvatarRepository.java
  UserAvatarController.java
  service/UserAvatarService.java + UserAvatarServiceImpl.java
```

| Endpoint | Behavior |
|---|---|
| `PUT /api/v1/users/me/avatar` (multipart, field `file`) | Validate → re-encode → upsert with `source=UPLOAD`. Returns 204. |
| `GET /api/v1/users/me/avatar` | Returns image bytes with `Content-Type`, `ETag` derived from `updated_at`, `Cache-Control: private, max-age=0, must-revalidate`; supports `If-None-Match` → 304. 404 if none. |
| `DELETE /api/v1/users/me/avatar` | Deletes the row. 204 (idempotent). |

All three resolve the user via `@CurrentUser` — no userId in the path, per project rules.

**Validation & processing (server-side, non-negotiable):**

- Multipart limits in `application.yaml`: `spring.servlet.multipart.max-file-size: 5MB` (+ matching request size).
- Check magic bytes, not just the declared content type. Accept JPEG, PNG, WebP input.
- **Re-encode** to JPEG, center-crop to square, downscale to max 512×512. Re-encoding is the security step: it strips EXIF (GPS!) and neutralizes malformed-image payloads. Library decision below.
- Reject anything that fails to decode with 400 + error code `INVALID_IMAGE`.

**Image library — decided: A (Thumbnailator):**

- **A — Thumbnailator (~100 KB jar, chosen):** clean fluent API over ImageIO for crop+resize+re-encode. Tiny, stable, justified.
- B — Plain `javax.imageio` + manual `Graphics2D`: zero dependencies but ~40 lines of fiddly scaling code and worse JPEG quality defaults.
- Note: ImageIO (both options) reads JPEG/PNG natively but **not WebP** — add `com.twelvemonkeys.imageio:imageio-webp` if WebP input should be accepted, otherwise restrict input to JPEG/PNG (the mobile client re-encodes to JPEG anyway, so JPEG/PNG-only is fine for v1 — Google avatars are JPEG too).

### Google picture import flow

1. Extend `GoogleIdentity` record with `String picture` (nullable) and have `GoogleIdTokenVerifier.verify()` read the `picture` claim (no failure if absent).
2. In `SocialAuthServiceImpl.loginWithGoogle`, after the user is resolved (all three paths: existing identity, linked, created), publish a `GoogleAvatarCandidateEvent(userId, pictureUrl)` when `picture != null`.
3. A new `@Async` `@TransactionalEventListener(phase = AFTER_COMMIT)` listener (same pattern as `WelcomeEmailListener`):
   - Skip if a `user_avatars` row already exists (any source) → uploaded or previously imported picture is never overwritten.
   - Rewrite the size suffix to `=s512-c`, download with `RestClient` — **only if the host is `*.googleusercontent.com` over https**, with a 5s timeout and a 5 MB read cap.
   - Run the same validate/re-encode pipeline, save with `source=GOOGLE`.
   - Any failure is logged and swallowed — avatar import must never break or slow down login (hence async after commit).

Re-login behavior: because the listener skips when a row exists, the Google picture is fetched at most once. If the user deletes their avatar and logs in with Google again, it gets re-imported — acceptable and arguably desirable.

### Mobile (Flutter) — Settings screen

New profile header section at the **top** of `features/settings/presentation/settings_screen.dart`, above the current groups:

```
[ CircleAvatar 72px | email | "Change photo" affordance ]
```

- Tap → bottom sheet (matching the existing `showModalBottomSheet` style in the file): **Take photo / Choose from gallery / Remove photo** (remove only shown when an avatar exists).
- New package: `image_picker`. Pick with `maxWidth: 1024, imageQuality: 85` — this also converts iOS HEIC to JPEG, so the backend only ever sees JPEG. No cropper package in v1; the server center-crops to square (Q3).
- Upload via multipart through the existing `dio` client.

**Offline handling:** avatar upload is **online-only** — it does not go through the drift outbox (a 100 KB blob in the outbox and conflict semantics aren't worth it for v1). If offline, show the existing error snackbar pattern ("connection required") (Q4).

**Display & caching (offline-first read path):**

- `GET /api/v1/users/me/avatar` needs the JWT header, so `Image.network` can't be used directly. Fetch bytes with dio and render with `Image.memory`.
- Cache the bytes in the app documents directory (`avatar.jpg` + stored ETag), following the feature's four-layer split:
  - `features/settings/data/avatar_repository.dart` — GET with `If-None-Match`, 304 → serve cached file; PUT/DELETE update the cache immediately (optimistic).
  - `features/settings/application/avatar_controller.dart` — `@riverpod` AsyncNotifier exposing `Uint8List?`; invalidated after upload/remove.
- Placeholder when no avatar: initial-letter CircleAvatar from the email.
- Clear the cached file on logout (add to the existing logout cleanup).
- l10n: EN + HU strings for the sheet actions, errors, and the header.

### Web

Out of scope for v1; the same three endpoints serve the web app later (settings page + `<img>` via fetched blob). Listed as Phase 4.

---

## Phased breakdown

### Phase 1 — Backend: avatar storage + endpoints

**Prompt:**

> In the Lifey backend (Spring Boot 4, Java 24), implement profile picture storage per `docs/22-profile-picture-plan.md`.
>
> - Flyway `V39__user_avatars.sql` as specified.
> - `com.lifey.user`: `UserAvatar` entity, repository, `UserAvatarService`/`Impl`, `UserAvatarController` with `PUT/GET/DELETE /api/v1/users/me/avatar` (`@CurrentUser`, never a path userId).
> - Multipart max 5 MB (`application.yaml`). Validate magic bytes (JPEG/PNG), re-encode with Thumbnailator: strip metadata, center-crop square, max 512×512, JPEG quality 0.85. 400 `INVALID_IMAGE` on decode failure.
> - GET serves bytes with ETag (from `updated_at`) + `If-None-Match` → 304; 404 when absent.
> - Tests: upload→get roundtrip, oversized file, fake content type (PNG magic bytes with .jpg name is fine, executable bytes rejected), ETag 304, delete idempotency, cross-user isolation.

### Phase 2 — Backend: Google avatar import on social login

**Prompt:**

> Extend Lifey Google login to import the Google profile picture per `docs/22-profile-picture-plan.md`.
>
> - Add nullable `picture` to `GoogleIdentity`; read the `picture` claim in `GoogleIdTokenVerifier` (absence is not an error).
> - `SocialAuthServiceImpl`: publish `GoogleAvatarCandidateEvent(userId, pictureUrl)` after user resolution when picture is present.
> - Async `AFTER_COMMIT` listener (pattern: `WelcomeEmailListener`): skip if `user_avatars` row exists; enforce https + `*.googleusercontent.com` host; rewrite size suffix to `=s512-c`; download via `RestClient` (5s timeout, 5 MB cap); reuse the Phase 1 validate/re-encode pipeline; save with `source=GOOGLE`; log-and-swallow all failures.
> - Tests: import on first login, no overwrite when avatar exists, non-Google host rejected, download failure doesn't fail login.

### Phase 3 — Mobile: Settings profile header + upload

**Prompt:**

> In the Lifey Flutter app, add a profile picture section to Settings per `docs/22-profile-picture-plan.md`.
>
> - Profile header at the top of `settings_screen.dart`: 72px CircleAvatar (initial-letter fallback), user email, tap → bottom sheet with Take photo / Choose from gallery / Remove photo.
> - `image_picker` (camera + gallery, `maxWidth: 1024, imageQuality: 85`); iOS `Info.plist` camera/photo usage strings; Android needs no runtime permission for the photo picker on API 33+, verify the pre-33 path.
> - `avatar_repository.dart` (dio multipart PUT, GET with ETag + documents-dir file cache, DELETE) and `avatar_controller.dart` (`@riverpod`, run build_runner). Online-only: offline upload shows the standard error snackbar.
> - Optimistic UI on upload/remove; clear cached avatar file on logout; l10n EN+HU.

### Phase 4 — Web: settings avatar *(later)*

Same endpoints; upload input + preview on the web settings page, blob-fetch for display. No backend work.

---

## ✅ Decisions (answered 2026-07-03)

| # | Question | Decision |
|---|---|---|
| Q1 | Storage | **A — Postgres bytea** (`user_avatars` table); no new infra, avatar-only. Revisit object storage only if general photo features land |
| Q2 | Image processing lib | **A — Thumbnailator**; tiny dependency, cleaner + safer re-encode (EXIF stripping) |
| Q3 | Client-side crop UI | **A — none in v1**, server center-crops to square; add `image_cropper` later only if users ask for it |
| Q4 | Offline upload via outbox | **A — online-only upload**; blob-in-outbox complexity not worth it. Display path stays offline-capable via the file cache |

**Effective v1 scope: Phases 1–3 (backend storage + Google import + mobile settings UI).** Phase 4 (web) stays in this doc as a ready-to-run follow-up.
