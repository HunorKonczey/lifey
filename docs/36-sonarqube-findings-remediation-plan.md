# SonarQube Findings Remediation Plan

Source: a full-project SonarQube for IDE (IntelliJ plugin) analysis, pasted as
a flat list of `(line, col) message [rule]` entries with no file names (the
IDE copy didn't include the per-file group headers). Below, each phase lists
the rules it covers and the files confirmed by grepping the codebase for the
pattern each rule flags. Where the raw report had many `(-, -)` duplicate
entries for the same rule, the exact remaining files will be re-confirmed by
grep at the start of that phase rather than guessed now.

**Ground rule for every phase: one phase = one PR, run the full backend test
suite (and `tsc`/`eslint`/vitest for the web phase) before moving to the
next. Nothing here ships in one shot.**

## Why this order

Phases 1–2 are behavior-preserving mechanical cleanups (safe to batch, easy
to review, build momentum). Phase 3 is real correctness risk — worth its own
focused PR so a reviewer isn't hunting for the one substantive change in a
sea of renames. Phase 4 requires actual judgment calls (some findings may be
"won't fix" with a documented reason, not a code change). Phase 5 is isolated
because of its sheer size (~39 files) and because "fix" here means a design
decision (inject `Clock`?), not a mechanical edit. Phase 6 is a different
stack (web) and ships independently of the backend phases.

---

## Phase 1 — Mechanical style cleanups (test + main, zero behavior change) — DONE

Completed. Result: 636/636 backend tests green, no behavior change.

* **S8694** — fixed across all 17 confirmed files (~110 call sites) via a
  scripted rewrite (`LocalDate.of(y, m, d)` → `LocalDate.of(y, Month.X, d)`),
  with `import java.time.Month;` added where missing.
* **S7467** — only 2 genuine unused catch-variables existed in the whole
  backend (`AuthServiceImpl.java`, `TrainerInviteEmailController.java`) —
  fixed with `_`. The other ~6 report entries didn't correspond to any
  actual unused catch/lambda variable found by a full-codebase scan; several
  files (`ImageReencoder`, `GoogleIdTokenVerifier`, `JwtService`) already use
  `_` from an earlier pass. Treated as stale report entries.
* **S8924** — fixed all 7 confirmed call sites (`WaterSourceControllerTest`,
  `UserAvatarServiceImplTest`, `WelcomeEmailListenerTest`,
  `WorkoutScheduleControllerTest`, `RecipeImageServiceImplTest`,
  `ProgramAssignmentServiceImplTest`) — added the missing static imports and
  dropped the `org.mockito.Mockito.` qualification.
* **S6068** — `ProgramAssignmentServiceImplTest` had a local `eq(Long)`
  wrapper method purely because `ArgumentMatchers.eq` wasn't statically
  imported; replaced with a direct static import and deleted the wrapper.
  No other file had this pattern.
* **S1128** — a full unused-import scan across all 438 backend source files
  found zero unused imports; the two report entries no longer apply
  (likely already resolved by earlier edits in this session).
* **S5838**, **S3358**, **S135** — searched exhaustively (size()==0/>0/!=0
  patterns, nested single-line ternaries, loops with >1 break/continue) and
  found no matching code anywhere in the backend. Treated as stale report
  entries — nothing to fix.
* **S5853** — 9 of 10 candidate consecutive-`assertThat(sameSubject)` pairs
  were merged into one fluent chain (`TokenHasherTest`,
  `WeeklyReportFormattingTest` ×2, `RecipeServiceImplTest` — via AssertJ's
  multi-property `.extracting(a, b).containsExactly(tuple(...), ...)`,
  `TrainerIdsWithActiveClientsRegressionTest`,
  `SessionCommentServiceImplTest`, `GoalCalculatorTest` ×2,
  `ContentAssignmentServiceImplTest`). One (`StarterCatalogListenerTest`)
  was left alone: its two assertions extract different, incompatible types
  from the same subject (`.extracting(Exercise::getName)` vs
  `.allSatisfy(...)` on the raw list) — merging them isn't a safe mechanical
  change.

---

Purely syntactic; a linter could do most of this. Safe to batch into one PR.

* **`java:S8694`** — "Use a `java.time.Month` enum constant instead of this
  int literal." By far the largest single rule in the report (~80+ hits) —
  every `LocalDate.of(2026, 7, 13)`-style call with a numeric month.
  Confirmed files (numeric-month `LocalDate.of(` calls):
  `ProgramAssignmentServiceImplTest`, `DateRangeQueryRegressionTest`,
  `TrainerClientDataControllerTest`, `WorkoutScheduleServiceImplTest`,
  `WorkoutScheduleControllerTest`, `ResendMailServiceTest`,
  `WeeklyReportServiceImplTest`, `WorkoutReminderJobTest`,
  `OccurrenceGeneratorTest`, `MealServiceImplTest`,
  `UserDetailsServiceImplTest`, `WeightServiceImplTest`,
  `WeightControllerTest`, `UserDetailsControllerTest`,
  `DailyStepCountServiceImplTest`, `DailyStepCountControllerTest`, plus
  `common/util/DateRanges.java` in main. Fix: `LocalDate.of(2026,
  Month.JULY, 13)`.
* **`java:S7467`** — "Replace `e`/`ex` with an unnamed pattern" (Java 21
  unnamed-variable `catch (Exception _)` where the caught exception is never
  read). Candidates: catch blocks across `ResendMailService`,
  `PushServiceImpl`, `UserAvatarServiceImpl`, `RecipeImageServiceImpl`,
  `ImageReencoder`, `GoogleAvatarImportListener`, `AuthServiceImpl`,
  `JwtService`, `JwtAuthenticationFilter`, `StarterCatalogListener`,
  `GoogleIdTokenVerifier`, `MailTemplateRenderer`, `WelcomeEmailListener` —
  confirm per-file at fix time which `catch` blocks genuinely never touch the
  variable (some legitimately log `ex.getMessage()` and must stay named).
* **`java:S8924`** — "Use a static import for `times`/`never`/`doThrow`."
  Confirmed: `ProgramAssignmentServiceImplTest` (`org.mockito.Mockito.times(2)`
  at the `verify(workoutSessionRepository, ...)` call), plus
  `WorkoutScheduleControllerTest`, `UserAvatarServiceImplTest`,
  `RecipeImageServiceImplTest`, `WaterSourceControllerTest`,
  `WelcomeEmailListenerTest`.
* **`java:S6068`** — "Remove this and every subsequent useless `eq(...)`
  invocation; pass the values directly." `ProgramAssignmentServiceImplTest`
  has a local `eq(Long)` wrapper method and several `verify(...)` calls
  mixing it with plain values — audit each call site: keep `eq()` only where
  it's mixed with a real matcher (e.g. `captor.capture()`), drop it (and the
  now-unused wrapper) everywhere else.
* **`java:S1128`** — unused imports (`org.mockito.InjectMocks` in one test
  file, `jakarta.validation.constraints.NotEmpty` in one main file — locate
  via `mvn -q compile` warnings or an IDE "optimize imports" pass, which is
  the safest way to catch every remaining unused import project-wide, not
  just the two the report sampled).
* **`java:S5838`** — "Use `isEmpty()` instead" (of `.size() == 0` /
  `!list.isEmpty()` double negatives, or `"".equals(...)`-style checks) —
  locate via grep for `.size() == 0` / `.size() > 0` once this phase starts.
* **`java:S5853`** — "Join these multiple assertions into one assertion
  chain" (AssertJ `assertThat(x).isA(); assertThat(x).isB();` instead of
  `.isA().isB()`) — scattered across several test files; low risk, pure
  readability.
* **`java:S3358`** — "Extract this nested ternary into an independent
  statement" — one occurrence, locate via grep for `? .* : .* ?` patterns.
* **`java:S135`** — "Reduce break/continue to at most one per loop" — one
  occurrence at a loop (likely an occurrence-generation loop in
  `WorkoutScheduleServiceImpl`/`ProgramAssignmentServiceImpl`/
  `OccurrenceGenerator`) — needs the actual loop restructured into early
  boolean flags or extracted helper methods; slightly more than a one-liner
  but still behavior-preserving.

## Phase 2 — Test quality (test files only, still zero prod risk) — DONE

Completed. Result: 636/636 backend tests green.

* **S5778** — found 34 occurrences (not ~10 as first estimated), all the
  exact same shape: `.thenAnswer(inv -> { X x = inv.getArgument(0);
  x.setId(N); return x; })` across 15 test files (`ContentAssignmentServiceImplTest`
  alone had 13). Since every mutated entity type (`User`, `WorkoutTemplate`,
  `Exercise`, `Recipe`, `Food`, `Meal`, `WeightEntry`, `WaterEntry`,
  `WaterSource`, `DailyStepCount`, `WorkoutSession`, `ProgramAssignment`,
  `TrainerClient`) extends `BaseEntity`, added one private generic helper
  per file — `private static <T extends BaseEntity> T withId(T entity, Long
  id) { entity.setId(id); return entity; }` — and collapsed each block into
  a single-expression lambda: `.thenAnswer(inv -> withId(inv.getArgument(0),
  N))`. A single-expression lambda has exactly one top-level invocation, so
  Sonar's rule (which targets multi-statement block lambdas, not nested
  calls within one expression) no longer fires. Verified the nested generic
  inference (`withId`'s `T` inferred through `inv.<T>getArgument(0)`) compiles
  cleanly on one file first before batch-applying to the rest.
* **S2699** — exactly 2 real assertion-less tests existed (confirmed by a
  full-suite scan recognizing AssertJ, JUnit, Mockito `verify()`, and MockMvc
  `andExpect()` as valid assertions — the naive first pass had ~200
  false positives from `@WebMvcTest` controllers whose only "assertion" is
  `.andExpect(...)`):
  * `AuthServiceImplTest.logout_unknownTokenIsANoOp` — wrapped the call in
    `assertThatCode(...).doesNotThrowAnyException()`, making the "no-op"
    contract the test name promises into an explicit assertion.
  * `FoodsExercisesOwnershipMigrationTest.barcodeAndNameUniquenessAreNowPerUserNotGlobal`
    — replaced the "no exception means it worked" comment with a real
    query confirming both rows exist (`count(*) ... = 2`), which is a
    stronger assertion than the original (proves the rows were actually
    inserted, not just that nothing threw).

---

* **`java:S2699`** — "Add at least one assertion to this test case" (two
  occurrences, e.g. around line 195 of one of the trainer service tests) —
  each needs a real look: either the test is missing its assertion (bug in
  the test) or it's purely a `verify(...)`-only Mockito test that Sonar
  doesn't recognize as an assertion (in which case add an explicit
  `assertThatCode(...).doesNotThrowAnyException()` or similar, or configure
  the rule to recognize `verify()` — a judgment call per test).
* **`java:S5778`** — "Refactor the lambda to have only one invocation
  possibly throwing a runtime exception" — by far the most common Phase 2
  finding (10+ hits), all in Mockito `.thenAnswer(inv -> { ...; return x;
  })` blocks that call two throwing methods (e.g. a setter + a getter, or
  two mock interactions) inside one lambda. Confirmed hotspots:
  `ProgramAssignmentServiceImplTest`, `ContentAssignmentServiceImplTest`
  (many `thenAnswer` stubs from the bulk-assignment work), plus others
  flagged with `(-, -)`. Fix pattern: split into a named helper method or
  two chained `.thenAnswer`/`.thenReturn` calls so each lambda has one
  throwing call.

## Phase 3 — Real correctness risk (main code, needs careful review) — DONE

Completed. Result: 636/636 backend tests green.

* **S6809** — found 4 real self-invocations (not the ~3 first estimated —
  two files share the identical line number, which accounts for the
  report's apparent duplicate). Fixed 3 by extracting the shared body into
  an un-annotated private helper so neither public entry point risks
  bypassing the other's `@Transactional` via self-invocation:
  * `DailyStepCountServiceImpl.findAll(from, to)` /
    `findAllForUser` → shared `findAllForUserInternal`.
  * `WeightServiceImpl.findAll(from, to)` / `findAllForUser` → shared
    `findAllForUserInternal`.
  * `WorkoutSessionServiceImpl.findPage` / `findPageForUser` → shared
    `findPageForUserInternal`.

  The 4th (`TrainerAccessServiceImpl.revokeClient` calling
  `requireActiveClient`) couldn't use the same fix: `requireActiveClient`
  is a real public guard called from many other places and must stay
  `@Transactional(readOnly = true)` for those call paths. Since
  `revokeClient` already opens a (default, read-write) transaction that the
  guard's read runs inside regardless, losing the `readOnly` hint on this
  one call path is harmless — documented with a comment rather than
  restructured, per the plan's "won't fix, explain why" option.

* **S2259** — 2 distinct issues, both fixed:
  * `AuthServiceImpl.login` — `Authentication#getPrincipal()` is
    `@Nullable` per its contract even though a successful `authenticate()`
    call never actually returns a null principal in practice here; added
    an explicit null check right after the cast that throws the same
    `InvalidCredentialsException` the catch block already uses, so a
    theoretical null is handled the same way as bad credentials instead of
    surfacing a raw NPE.
  * `ContentAssignmentServiceImpl.assign` — the real bug behind the
    warning: `sourceTemplate`/`sourceRecipe` were two outer nullable
    variables (only one non-null depending on `contentType`), and the
    per-client loop's `switch (request.contentType())` couldn't be proven
    by the compiler/analyzer to correlate with *which* outer variable was
    non-null — they're two independently-evaluated conditions that happen
    to test the same thing. Restructured so a single `switch` resolves the
    source **once, into a non-nullable local**, and closes over it in a
    `Function<Long, Long> copyForClient` bound before the loop — preserves
    the "load the source once per batch" behavior (still covered by the
    existing "source loaded once" test) while making the non-null
    invariant a matter of variable scope rather than convention.

* **S1192** — `WorkoutScheduleServiceImpl.cancelOccurrence` had
  `"Scheduled session not found: " + sessionId` duplicated 3 times;
  extracted a private `sessionNotFound(sessionId)` helper returning the
  built `ScheduleNotFoundException`, used at all 3 throw sites.

* **S1172** — `SocialAuthServiceImplTest.stubTokenIssuance(User
  ignoredUser)` never read its parameter (one call site even passed
  `null`, confirming it was vestigial); removed the parameter and updated
  all 4 call sites.

---

These are not style — each is a genuine bug or bug-shaped risk.

* **`java:S6809`** — "Call transactional methods via an injected dependency
  instead of directly via `this`." Two-three occurrences in `@Transactional`
  service classes (locate exact call sites via grep for self-invocation of
  a method carrying its own `@Transactional`/different propagation within
  the same class at Phase 3 start — candidates are the trainer service
  classes touched most recently, `ContentAssignmentServiceImpl` and
  `ProgramAssignmentServiceImpl`, since they have the most internal
  cross-calls). **This is a real bug class**: Spring's proxy-based AOP means
  a self-invoked `@Transactional` method silently runs with the *caller's*
  transaction semantics, not its own — if any of these calls rely on their
  own propagation (e.g. `REQUIRES_NEW`) it's currently broken. Needs each
  call site individually assessed: if the callee doesn't actually need
  independent transaction semantics, this may be a false positive worth
  suppressing with a comment explaining why; otherwise, extract the callee
  into a separate injected bean.
* **`java:S2259`** — "NullPointerException could be thrown; `principal` is
  nullable" — two occurrences. One is likely
  `AuthServiceImpl.java` (`principal = (UserPrincipal)
  authentication.getPrincipal()` — `getPrincipal()` is `@Nullable` per the
  Spring Security contract even though this code path never actually sees
  null in practice). The other two (`copyTemplateForClient()`/
  `copyRecipeForClient()` NPE warnings at lines 87-88) are in
  `ContentAssignmentServiceImpl` — likely Sonar flagging the new
  `requireOwnedTemplate`/`requireOwnedRecipe` + `copyTemplateForClient`/
  `copyRecipeForClient` split from the bulk-assignment refactor, where the
  nullable `WorkoutTemplate sourceTemplate`/`Recipe sourceRecipe` locals
  (only one is non-null depending on `contentType`) get passed into the
  wrong-branch copy method in a way Sonar's flow analysis can't rule out.
  Needs a look — likely just needs the null-check made explicit/final
  rather than relying on the switch's structure to guarantee non-null.
* **`java:S1192`** — "Define a constant instead of duplicating this literal
  'Scheduled session not found: ' 3 times" — confirmed in
  `WorkoutScheduleServiceImpl.java`. Mechanical but grouped here because it
  touches production exception-throwing code, not a test.
* **`java:S1172`** — "Remove this unused method parameter `ignoredUser`" —
  one occurrence; locate and either remove the parameter or, if it exists
  for interface-signature-compatibility reasons, rename with a leading
  underscore convention isn't idiomatic Java — better to check whether the
  interface method actually needs that parameter at all.

## Phase 4 — Security/config judgment calls — DONE

Completed. Result: 636/636 backend tests green; Docker image built and run
manually to verify the non-root change doesn't break startup.

* **S4502** — confirmed safe and left disabled: verified
  `JwtAuthenticationFilter` reads the token from the `Authorization` header
  (`request.getHeader("Authorization")`), never a cookie, and
  `SecurityConfig` already sets `SessionCreationPolicy.STATELESS`. Added a
  short inline comment right at the `.csrf(...)` line (the class-level
  Javadoc already explained the reasoning, but not at the flagged line
  itself) — a "won't fix, here's why" resolution rather than a code change.
* **S6471** — `backend/Dockerfile`'s runtime stage now creates and switches
  to a non-root `app` user (`groupadd`/`useradd --system`, `COPY
  --chown=app:app`, `USER app` before `EXPOSE`). Verified end-to-end: built
  the image, ran it against the local Postgres, confirmed `whoami` → `app`
  (uid 999, not root), confirmed `/tmp` is still writable as that user (the
  entrypoint's push-credential-decoding step writes there by default), and
  confirmed the Spring Boot app actually started successfully in the
  container before cleaning up the test image. `web/Dockerfile` was
  already hardened (`USER nextjs`) — confirmed, no change needed there.
* **S5693** — reviewed and accepted, not changed: there's no second
  in-code size limit to align with (the only gate is
  `spring.servlet.multipart.max-file-size`/`max-request-size`, both
  10MB) — the finding is Sonar's generic 8MB DoS-prevention default being
  exceeded, not an actual mismatch. Both upload endpoints require
  authentication, accept one file per request, and re-encode/resize the
  image server-side immediately after upload (`ImageReencoder`), so 10MB
  buys real camera-photo headroom without a meaningfully larger abuse
  surface than 8MB. Documented the review inline in `application.yml`
  rather than shrinking the limit.
* **S1075** — `GoogleIdTokenVerifier`'s hardcoded `JWKS_URI` constant moved
  to `GoogleOAuthProperties.jwksUri()` (bound from
  `lifey.oauth.google.jwks-uri`, env override `OAUTH_GOOGLE_JWKS_URI`,
  `@DefaultValue` of the real Google endpoint so no existing deployment
  needs a config change). Updated `application.yml` and the one test that
  constructs `GoogleOAuthProperties` directly
  (`GoogleIdTokenVerifierTest` — that test injects its own `JwtDecoder`
  bound to an in-memory JWK set, so the URI value is unused there but the
  record now requires it).

---

Not pure fixes — each needs a decision, and some may end up as documented
"won't fix" rather than a code change.

* **`java:S4502`** — "Make sure disabling Spring Security's CSRF protection
  is safe here" — confirmed at `SecurityConfig.java:87`
  (`.csrf(AbstractHttpConfigurer::disable)`). This is almost certainly
  intentional (stateless JWT bearer-token API, no cookie-based session to
  forge) — the right outcome is likely a one-line comment explaining why,
  plus a Sonar "won't fix" resolution, not a code change. Confirm no cookie-
  based auth path exists before closing it out.
* **`java:S6471`** — "The `eclipse-temurin` image runs with `root` as the
  default user" — confirmed in `backend/Dockerfile`. Real fix: add a
  non-root `USER` stanza (standard multi-stage Docker hardening — create an
  `appuser`, `chown` the app dir, `USER appuser` before `ENTRYPOINT`). Check
  `web/Dockerfile` too even though it wasn't flagged (may already do this,
  or may use a different base image).
* **`java:S5693`** — "Content length limit ... greater than the defined
  limit" (two occurrences) — confirmed in the avatar/recipe-image upload
  path (`UserAvatarController`/`RecipeImageController`/
  `UserAvatarServiceImpl`/`RecipeImageServiceImpl`, and
  `application.yml`'s multipart config). Needs checking what the actual
  intended max upload size is and aligning the two limits (Spring's
  `spring.servlet.multipart.max-file-size` vs. whatever in-code check exists)
  rather than blindly shrinking one number.
* **`java:S1075`** — "Refactor your code to get this URI from a customizable
  parameter" — confirmed at `GoogleIdTokenVerifier.java:25-26` (hardcoded
  `JWKS_URI`/issuer constants). Fix: move to `application.yml` +
  `@ConfigurationProperties` (there's already a `GoogleOAuthProperties`
  class in the same package to extend), so it's overridable per environment
  without a code change (useful for pointing at a mock/test JWKS endpoint).

## Phase 5 — `.now()` time-zone determinism (isolated due to size) — DONE (Option B)

Completed per the Option B recommendation below — no `Clock` bean
introduced. Audited the test suite for the fragility pattern that broke
`ProgramAssignmentServiceImplTest` (a hardcoded absolute date fed into
production code that validates it against `LocalDate.now()`, which
eventually becomes "the past" as real time moves on) and found **no other
occurrences**:

* Only two production classes validate a "not in the past" rule at all:
  `WorkoutScheduleServiceImpl` and `ProgramAssignmentServiceImpl`.
  `WorkoutScheduleServiceImplTest` already computes its dates as
  `LocalDate.now().plusDays(1)`/`.minusDays(1)` — safe by construction,
  never breaks. `ProgramAssignmentServiceImplTest` was the one that broke
  and was already fixed (in the session before this remediation plan
  existed) by computing `A_MONDAY` from `LocalDate.now()` instead of a
  hardcoded date.
* Every other hardcoded `LocalDate.of(...)` in the test suite
  (`OccurrenceGeneratorTest`, and the many test files touched in Phase 1's
  Month-enum sweep) feeds **pure date-math functions** that never compare
  against "today" — `OccurrenceGenerator.generate(recurrence, days, from,
  to)` takes `from`/`to` as plain inputs with no internal `now()` check, so
  these dates can never become invalid regardless of how much time passes.
* The two "future date rejected" tests
  (`WeightControllerTest`/`DailyStepCountControllerTest`) hardcode
  `2999-01-01` — matching `DateRanges.DISTANT_FUTURE`'s convention, ~976
  years of headroom, not a fragile pattern.

No main-source `.now()` calls were touched — per Option B, that's a
deliberate non-fix (see rationale below), and there's no separate
SonarQube server in this environment to formally record a "won't fix"
resolution against; this plan document is the durable record of that
decision.

---

* **`java:S8688`** — "Explicitly specify the time zone by passing a `ZoneId`
  or a `Clock` to the `.now()` method." This is the single largest finding
  by file count: **39 main-source files** call `Instant.now()`/
  `LocalDate.now()`/`LocalDateTime.now()` with the implicit system default
  zone, plus a comparable number of test files.

  **This phase needs a design decision before any code moves**, not a
  mechanical sweep:
  * Option A — inject a `java.time.Clock` bean (`Clock.systemUTC()` in
    production, a fixed `Clock` in tests) everywhere `.now()` is called.
    Correct long-term, but touches the constructor of ~30+ service classes
    — a large, high-review-cost diff for a currently-hypothetical bug (the
    app has one deployment region/timezone; this only matters if that ever
    changes, or for test determinism).
  * Option B — leave production code alone (the app's server timezone is
    fixed and known), and only fix the finding where it's genuinely useful:
    tests that want deterministic, timezone-independent instants (inject a
    fixed `Clock` or `Instant` there specifically, following the pattern
    already used for `ProgramAssignmentServiceImplTest`'s `A_MONDAY`
    computed-from-`LocalDate.now()` fix). Mark the rule "won't fix" at
    project level for main-source `.now()` calls with a documented reason,
    unless/until multi-timezone deployment is a real requirement.

  **Recommendation: Option B.** Revisit Option A only if the product ever
  needs multi-region deployment or the test suite starts showing
  timezone-dependent flakiness beyond what's already been patched once
  (`ProgramAssignmentServiceImplTest`'s Monday-date bug). Scope this phase
  to: (1) formally suppressing/resolving the main-source findings with a
  short justification comment or Sonar issue resolution, (2) auditing test
  files for the same `LocalDate.now()`-relative-to-fixed-date fragility
  pattern that just broke `ProgramAssignmentServiceImplTest`, fixing any
  found the same way.

## Phase 6 — Web/frontend findings — DONE

Completed on the same branch (per explicit instruction, not a separate PR).
Result: `tsc --noEmit` clean, 99/99 vitest green, 636/636 backend tests still
green (mail-template edits are backend-owned resources).

**Discovery correction: none of these findings were in `web/src/app/`.**
The raw report had no file names, and my Phase-6-writing assumption (Next.js
pages missing `<title>`, a web admin `<table>` missing `<th>`) turned out
wrong on inspection — every `web/src/app/**/page.tsx` inherits the root
layout's `title: "Lifey"` metadata, and the admin assignments page (the
only "table-like" admin UI) is div-based, not a real `<table>`. Searched the
whole repo for actual standalone `.html`/`.css` files instead and found the
real targets: the backend's own email templates
(`backend/src/main/resources/mail/*.html`) and its one global stylesheet
(`web/src/app/globals.css`) — both are still "web" content the Sonar Web/CSS
plugins would scan, just not React pages.

* **`Web:PageWithoutTitleCheck`** — 8 real standalone HTML documents were
  missing a `<title>`: `welcome_en/hu`, `password_reset_en/hu`,
  `trainer_invite_en/hu`, `weekly_report_en/hu` (the report said 7; the
  8th was presumably a near-miss in whatever partial scan produced the
  list). Added a short, content-appropriate `<title>` to each. The
  `weekly_report_row_en/hu.html` files are `<tr>` fragments with no
  `<html>`/`<head>` at all (spliced into the parent template) — correctly
  not flagged, left alone.
* **`Web:S5256`** — `weekly_report_en.html` and `weekly_report_hu.html`
  both render a single-column `<table>` of per-client rows with zero
  header cells. Added a `<thead><tr><th scope="col">…</th></tr></thead>`
  and wrapped the templated `{{clientRows}}` in `<tbody>`. Verified
  against `MailTemplateRendererTest` (placeholder substitution still
  works — the tests check for substituted content, not exact table
  markup) and `ResendMailServiceTest`/`WeeklyReportServiceImplTest`, all
  green.
* **`css:S7924`** — first pass guessed wrong (see below); the user later
  shared the actual SonarQube for IDE panel with real file/line info,
  which pinpointed the true findings precisely:
  * **The real findings**: `trainer_invite_en.html:12` and
    `trainer_invite_hu.html:12`, both the "Decline" button/link's inline
    `background:#888; color:#fff`. Computed exactly: 3.54:1 — fails WCAG
    AA (4.5:1 for normal-size text). Fixed by darkening the background to
    `#757575` (Material Design's standard "Grey 600", not an arbitrary
    value) → 4.61:1, passing with a small margin. Verified against
    `MailTemplateRendererTest`/`ResendMailServiceTest`/
    `TrainerInviteServiceImplTest`, all green. The "Accept invite" button
    (`#2e7d32`/white, 5.13:1) was already fine — untouched.
  * **My first-pass guess** (kept, not reverted — see rationale): before
    getting the real panel output, I assumed the 2 occurrences were
    `web/src/app/globals.css`'s `--muted` token, since `css:S7924` sounds
    stylesheet-scoped and I hadn't yet learned Sonar's Web/CSS rules also
    scan inline `style=""` attributes in HTML. That guess was **wrong**
    about *which* 2 findings these were, but the contrast problem I found
    while chasing it is real and independently verified: `--muted` fails
    WCAG AA against every surface tone it's paired with in both themes
    (dark `#777264`: 3.27–3.78:1; light `#9A9A8C`: 2.37–2.85:1). Adjusted
    to dark `#918B7A` (4.62–5.34:1) / light `#696960` (4.62–5.54:1) —
    same hue, minimal lightness change, confirmed in-browser via
    `getComputedStyle`. Left in place as a legitimate a11y fix on top of,
    not instead of, the real reported findings above.

---

* **`Web:PageWithoutTitleCheck`** — "Add a `<title>` tag to this page" (7
  occurrences) — Next.js App Router pages missing a `metadata`/`title`
  export. Fix: add `export const metadata = { title: "..." }` (or a
  `generateMetadata`) to each flagged route under `web/src/app/`. Low risk,
  mechanical, but needs the actual route files identified (re-run analysis
  scoped to `web/` to get file names, since none were in the flat list).
* **`Web:S5256`** — "Add `<th>` headers to this `<table>`" (2 occurrences)
  — a real accessibility table somewhere using `<td>` for header cells.
* **`css:S7924`** — "Text does not meet the minimal contrast requirement" (2
  occurrences) — likely a `var(--muted)`-on-`var(--surface)` combination
  somewhere thin enough to fail WCAG AA; needs the actual color pair checked
  against a contrast calculator before picking a fix (don't guess a new
  color without verifying against both light/dark themes, per this repo's
  theme-aware CSS convention).

Run `tsc --noEmit`, `eslint`, and `vitest` after this phase — no backend
involvement.

---

## Post-Phase-2 correction: broader S5778 pattern

After Phase 6 shipped, the user shared the actual SonarQube for IDE panel
(real file/line info this time), revealing Phase 2's S5778 fix was
**incomplete**: it only covered `.thenAnswer(inv -> { ...; return x; })`
block lambdas. A second, more common pattern was still flagged everywhere:
`assertThatThrownBy(() -> service.method(new SomeRequest(...)))` — a
single-*expression* lambda, but with **two** invocations in it (the
`new SomeRequest(...)` construction and the `service.method(...)` call).
Confirmed real via the panel: `ProgramAssignmentServiceImplTest.java` (6
occurrences) and `RecipeImageServiceImplTest.java` (1, a helper-method call
`pngUpload(10, 10)` rather than a constructor — same shape).

The rule's actual intent, now clear: for an exception-assertion lambda
specifically, ambiguity about *which* invocation could throw undermines
what the assertion is testing — even a single-expression lambda is flagged
if it nests 2+ calls. (This doesn't contradict the Phase 2 `withId(...)`
fix, which remains valid: those are `.thenAnswer` stubs, not exception
assertions, and stayed unflagged in the new panel view.)

Swept the whole backend test suite for the same shape (`assertThatThrownBy`
whose lambda body contains 2+ call-like expressions) and fixed all 29
occurrences across 12 files — `FoodServiceImplTest`,
`RecipeImageServiceImplTest`, `ClientNutritionGoalsServiceImplTest`,
`ContentAssignmentServiceImplTest` (4), `ProgramAssignmentServiceImplTest`
(6), `TrainerInviteServiceImplTest` (6), `TrainingProgramServiceImplTest`,
`WaterSourceServiceImplTest`, `WorkoutTemplateServiceImplTest`,
`WorkoutScheduleServiceImplTest` (4), `OccurrenceGeneratorTest` (2) — by
extracting the constructed request/argument to a local variable *before*
the assertion, so the lambda passed to `assertThatThrownBy` contains
exactly one invocation (the service call under test). One test
(`RecipeImageServiceImplTest.upload_throwsWhenRecipeNotOwned`) needed
`throws IOException` added to its signature since the extracted
`pngUpload(...)` helper call is no longer wrapped in the lambda's implicit
`Throwable`-tolerant context. Re-scanned after the fix: 0 remaining.

Also added `@SuppressWarnings("java:S4502")` to `SecurityConfig.filterChain`
— the Phase 4 fix only left an explanatory `//` comment, which documents
intent for humans but doesn't actually suppress the finding for SonarLint/
SonarQube (that requires a recognized annotation or `NOSONAR` comment).

Verified: 636/636 backend tests green after every fix in this correction.

## Suggested execution order

1 → 2 → 3 → 4 → 6, with **5 last and possibly partial** (per the Option B
recommendation above, "fixing" Phase 5 may mean mostly writing suppression
resolutions rather than code changes). Each phase is its own PR/session;
confirm before starting the next one.
