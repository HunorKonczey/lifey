# Lifey Mobile (Flutter)

See root `../CLAUDE.md` for project-wide rules (Java/Maven backend rules don't apply here).

## Stack

- State management: `flutter_riverpod` (+ `riverpod_generator`/`build_runner` for generated providers — never hand-edit `*.g.dart`)
- Routing: `go_router`
- HTTP: `dio` (`lib/core/network/dio_client.dart`, `lib/core/network/api_config.dart`)
- Offline-first local cache: `drift` (SQLite) under `lib/core/local_db/`. Chosen over Isar — Isar 3.1.0 lacks an Android `namespace` and breaks AGP 8 builds, and Isar 4.x was still unstable when this was picked.
- Local-id generation: `uuid` (`lib/core/sync/client_id.dart`) — every entity gets a client-generated UUID (`clientId`) as its local primary key on creation, online or offline; the backend's integer id is stored as a nullable `serverId` once a create syncs. See `lib/core/sync/` for the outbox (`OutboxWriter`) and drain loop (`SyncEngine`) this enables.
- Connectivity detection: `connectivity_plus` (`lib/core/sync/connectivity_sync_controller.dart`) — triggers `SyncEngine.sync()` on connectivity restore, app resume, and a 60s foreground timer. No background sync while the app is fully closed (out of scope for this phase).

## Package structure

Feature-based, under `lib/features/<feature>/`:

- `domain/` — plain model classes (entities carry `clientId` + nullable `id`/`serverId`)
- `data/` — repositories: write to the local DB + enqueue an outbox entry (never call `dio` directly); read via Drift watch streams
- `application/` — Riverpod controllers/providers (`StreamNotifier` wrapping a repository's watch stream)
- `presentation/` — screens and widgets

Shared cross-feature code lives in `lib/shared/widgets/` and `lib/core/` (theme, router, network, storage).

## Conventions

- Run `dart run build_runner build` after changing any `@riverpod`-annotated provider.
- New features should follow the same four-layer split even if a layer is thin.
