# Lifey Backend (Spring Boot)

See root `../CLAUDE.md` for project-wide rules.

## Stack

- Spring Boot 4.1.0 parent, Spring Web, Spring Data JPA, Spring Security, Flyway (`spring-boot-flyway` + `flyway-database-postgresql`)
- Auth: JWT via `jjwt` 0.12.6 (api/impl/jackson) + refresh tokens persisted in DB
- Lombok (optional, annotation-processor wired in `maven-compiler-plugin`)
- API docs: springdoc-openapi (`OpenApiConfig`)
- Tests: JUnit via `spring-boot-starter-test`, `spring-boot-webmvc-test`, `spring-security-test`, Testcontainers (Postgres) — note the Surefire config attaches Mockito as a `-javaagent` (`maven-surefire-plugin` argLine), required for the inline mock maker on modern JDKs; don't remove it.

## Package structure

Feature-based under `com.lifey.<feature>/`, e.g. `auth/`, `user/`, `weight/`, `workout/exercise/`, `workout/template/`, `workout/session/`, `nutrition/food/`, `nutrition/meal/`, `nutrition/recipe/`, `statistics/`. Shared code in `common/` (`exception/`, `config/`, `domain/BaseEntity`).

Within each feature, typical layout:

- `<Entity>.java` — JPA entity (extends `BaseEntity`)
- `<Entity>Repository.java` — Spring Data JPA repository
- `<Entity>Service.java` (interface) + `<Entity>ServiceImpl.java` — business logic
- `<Entity>Mapper.java` — entity <-> DTO mapping
- `<Entity>Controller.java` — REST endpoints
- `dto/` — `*Request.java` / `*Response.java`

Auth-specific pieces live flat in `auth/`: `JwtService`, `JwtProperties`, `TokenHasher`, `CurrentUserProvider`, `UserPrincipal`, `RefreshToken`/`RefreshTokenRepository`, plus dedicated exceptions (`InvalidCredentialsException`, `InvalidTokenException`, `TokenExpiredException`, `TokenRevokedException`).

## Conventions

- Always add a Service interface + Impl, even for simple CRUD — matches existing features.
- New entities must extend `BaseEntity` and be scoped to a user (per root rule).
- New tables/columns go through a new Flyway migration, never edit an applied one.
- Note: root `CLAUDE.md` says "Use Java 21" but `pom.xml` pins `<java.version>24</java.version>` — the pom is authoritative for this repo; flag this discrepancy if it matters for your task instead of silently picking one.
