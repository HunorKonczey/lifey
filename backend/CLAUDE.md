# Lifey Backend (Spring Boot)

See root `../CLAUDE.md` for project-wide rules.

## Stack

- Spring Boot 4.1.0 parent, Spring Web, Spring Data JPA, Spring Security, Flyway (`spring-boot-flyway` +
  `flyway-database-postgresql`)
- Auth: JWT via `jjwt` 0.12.6 (api/impl/jackson) + refresh tokens persisted in DB
- Lombok (optional, annotation-processor wired in `maven-compiler-plugin`)
- API docs: springdoc-openapi (`OpenApiConfig`)
- Tests: JUnit via `spring-boot-starter-test`, `spring-boot-webmvc-test`, `spring-security-test`, Testcontainers (
  Postgres) — note the Surefire config attaches Mockito as a `-javaagent` (`maven-surefire-plugin` argLine), required
  for the inline mock maker on modern JDKs; don't remove it.

## Package structure

Feature-based under `com.lifey.<feature>/`, e.g. `auth/`, `user/`, `weight/`, `workout/exercise/`, `workout/template/`,
`workout/session/`, `nutrition/food/`, `nutrition/meal/`, `nutrition/recipe/`, `statistics/`. Shared code in `common/` (
`exception/`, `config/`, `domain/BaseEntity`).

Within each feature, typical layout:

- `<Entity>.java` — JPA entity (extends `BaseEntity`)
- `<Entity>Repository.java` — Spring Data JPA repository
- `service/` — `<Entity>Service.java` (interface) + `<Entity>ServiceImpl.java`, and any other interface+impl pairs (e.g.
  `BarcodeLookupService`/`Impl` in `nutrition/food/`). Only created once a feature has 2+ files of this kind; a
  single-file feature keeps its service flat.
- `<Entity>Mapper.java` — entity <-> DTO mapping
- `<Entity>Controller.java` — REST endpoints
- `dto/` — `*Request.java` / `*Response.java`

General rule: once a feature package accumulates 2+ files of the same kind (services, exceptions, repositories,
entities), group them into a same-named subpackage (`service/`, `exception/`, `repository/`, `entity/`, etc).
Single-of-a-kind files (one controller, one mapper, one repository) stay flat in the feature root. Classes/methods used
only from within their own subpackage can stay package-private; anything reached from a sibling subpackage (e.g. a
`service/` class calling a root-level mapper) must be `public`.

`auth/` (the largest feature) is organized as:

- `auth/` (flat) — `AuthController`, `JwtService`, `JwtProperties`, `JwtAuthenticationFilter`,
  `JwtAuthenticationEntryPoint`, `JwtAccessDeniedHandler`, `SecurityConfig`, `TokenHasher`, `CurrentUser`,
  `CurrentUserProvider`, `UserPrincipal`, `GoogleIdTokenVerifier`, `GoogleIdentity`, `GoogleOAuthProperties`,
  `UserRegisteredEvent`, `WelcomeEmailListener`, `PasswordResetTokenCleanupJob`
- `auth/service/` — `AuthService`/`Impl`, `PasswordResetService`/`Impl`, `SocialAuthService`/`Impl`,
  `CustomUserDetailsService`
- `auth/exception/` — `IncorrectPasswordException`, `InvalidCredentialsException`, `InvalidResetCodeException`,
  `InvalidSocialTokenException`, `InvalidTokenException`, `SamePasswordException`, `TokenExpiredException`,
  `TokenRevokedException`, `UnverifiedEmailException`
- `auth/repository/` — `PasswordResetTokenRepository`, `RefreshTokenRepository`, `UserIdentityRepository`
- `auth/entity/` — `PasswordResetToken`, `RefreshToken`, `UserIdentity`, `Provider`
- `auth/dto/` — requests/responses

`mail/` follows the same idea: `MailConfig`, `MailLanguage`, `MailLanguageResolver`, `MailProperties`,
`MailTemplateRenderer` stay flat; `MailService`/`ResendMailService` live in `mail/service/`.

`nutrition/openfoodfacts/` groups `OpenFoodFactsClient`/`Impl` into `nutrition/openfoodfacts/client/`.

## Conventions

- Always add a Service interface + Impl, even for simple CRUD — matches existing features.
- New entities must extend `BaseEntity` and be scoped to a user (per root rule).
- New tables/columns go through a new Flyway migration, never edit an applied one.
- Note: root `CLAUDE.md` says "Use Java 21" but `pom.xml` pins `<java.version>24</java.version>` — the pom is
  authoritative for this repo; flag this discrepancy if it matters for your task instead of silently picking one.
