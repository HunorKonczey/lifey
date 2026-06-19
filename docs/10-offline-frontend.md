# 01 - Offline-First Synchronization Architecture

## 1. Goal

1. Implement offline-first synchronization for the Lifey Flutter mobile application.
2. The application must remain fully usable without network connectivity.
3. All user actions should be stored locally and synchronized automatically when connectivity is restored.
4. Background synchronization while the application is closed is not required in this phase.

## 2. Local Database

1. Introduce a Drift-based SQLite database under:

```text
mobile/lib/core/local_db/
```

2. Store all existing entities locally, including:

    * Weight Entries
    * Foods
    * Recipes
    * Recipe Ingredients
    * Meals
    * Meal Entries
    * Exercises
    * Workout Templates
    * Template Exercises
    * Workout Sessions
    * Planned Exercises
    * Workout Sets
    * Water Sources
    * Water Entries
    * User Settings

3. Every entity must contain:

    * `clientId` (UUID, primary key)
    * `serverId` (nullable backend identifier)

4. New records are created locally first and receive a server identifier only after successful synchronization.

## 3. Outbox Pattern

1. Introduce a `pending_operations` table.

2. Required fields:

    * clientId
    * entityType
    * operation (create/update/delete)
    * payloadJson
    * dependsOnClientId (nullable)
    * status (pending/syncing/failed)
    * createdAt
    * lastError

3. All write operations must create an outbox entry.

4. Repositories must never call Dio directly.

## 4. Sync Engine

1. Implement a generic `SyncEngine`.

2. Responsibilities:

    * Process pending operations in dependency order.
    * Handle parent-child relationships.
    * Wait for parent synchronization when required.
    * Execute API calls through the existing `dioClientProvider`.
    * Update server IDs after successful creation.
    * Update local references that depended on temporary client IDs.
    * Mark operations as failed when synchronization fails.
    * Retry only network-related failures automatically.

## 5. Repository Migration

1. Refactor repositories to follow an offline-first approach.

2. Write operations:

    * Persist to local database.
    * Create outbox entries.

3. Read operations:

    * Read exclusively from the local database.
    * Expose Drift watch queries or Riverpod stream providers.

4. Create a migration plan for all repositories and identify every repository that must be updated.

## 6. Connectivity Integration

1. Use `connectivity_plus`.

2. Trigger synchronization when:

    * Connectivity is restored.
    * The application returns to the foreground.
    * A lightweight periodic timer executes while the application remains open.

3. True background synchronization is not required.

## 7. Pull Synchronization

1. When the application starts or connectivity returns:

    * Fetch the latest server state.
    * Refresh the local cache.
    * Preserve local pending changes that have not yet been synchronized.

2. Server data should become the source of truth once synchronization succeeds.

## 8. UI Requirements

1. Add a global offline indicator.

2. Display synchronization state on affected records:

    * Pending
    * Failed

3. Failed items should support:

    * Retry
    * Discard

4. Synchronization state should be visible but unobtrusive.

## 9. Implementation Order

1. Do not implement all features at once.

2. Start with Weight Tracking as a complete vertical slice:

    * Local schema
    * Repository migration
    * Outbox integration
    * Sync engine integration
    * UI synchronization indicators

3. Only after approval continue with:

    1. Water
    2. Settings
    3. Foods & Exercises
    4. Recipes & Meals
    5. Workout Templates & Sessions

## 10. Important Notes

1. The Workout domain is significantly more complex than the previous features.

2. Workout Templates, Sessions and Exercises currently rely on integer identifiers in several places.

3. These areas must be reviewed carefully because offline-created entities will not yet have server IDs.

4. The synchronization architecture must be designed around client-generated UUIDs as the primary local identifier.

5. Apply the same principle to nested Recipe and Meal structures.

## 11. Package Evaluation

1. Evaluate and justify the introduction of:

    * drift
    * connectivity_plus
    * uuid

2. If project rules require approval before introducing new dependencies, request confirmation before proceeding.

3. Update the relevant `CLAUDE.md` documentation with the reasoning behind the selected packages and architectural decisions.
