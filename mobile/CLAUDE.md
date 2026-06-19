# Lifey Mobile (Flutter)

See root `../CLAUDE.md` for project-wide rules (Java/Maven backend rules don't apply here).

## Stack

- State management: `flutter_riverpod` (+ `riverpod_generator`/`build_runner` for generated providers — never hand-edit `*.g.dart`)
- Routing: `go_router`
- HTTP: `dio` (`lib/core/network/dio_client.dart`, `lib/core/network/api_config.dart`)
- No local/offline storage yet. Avoid Isar 3.1.0 specifically — it lacks an Android `namespace` and breaks AGP 8 builds. If offline storage is needed, prefer drift, hive_ce, or Isar 4.x.

## Package structure

Feature-based, under `lib/features/<feature>/`:

- `domain/` — plain model classes
- `data/` — repositories (talk to backend via `dio`)
- `application/` — Riverpod controllers/providers (business logic, state)
- `presentation/` — screens and widgets

Shared cross-feature code lives in `lib/shared/widgets/` and `lib/core/` (theme, router, network, storage).

## Conventions

- Run `dart run build_runner build` after changing any `@riverpod`-annotated provider.
- New features should follow the same four-layer split even if a layer is thin.
