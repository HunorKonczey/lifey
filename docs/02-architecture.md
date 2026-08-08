# Technical Architecture

## Frontend

Technology:

* Flutter

Reasons:

* Single codebase
* Native iOS support
* Future Android support
* Strong ecosystem

State management:

* Riverpod

Routing:

* GoRouter

Networking:

* Dio

Local storage:

* Hive or Isar

## Backend

Technology:

* Spring Boot 4
* Java 24

Modules:

* Authentication
* Nutrition
* Recipes
* Workouts
* Weight Tracking

## Chat service

The trainer↔client chat runs as a **second Spring Boot service** (`chat/`,
deployed as `lifey-chat`), not inside the API. Reasoning and the full migration
record: [chat/44-chat-service-extraction-plan.md](chat/44-chat-service-extraction-plan.md).

The short version — it was not about load:

* **Blast radius.** The chat holds long-lived SSE connections; a leak there used
  to be able to OOM the whole API, workout log and all.
* **Different resource profile and scaling axis.** The API scales on requests,
  the chat on concurrent connections.
* **It was already the most self-contained module** — nothing pointed into it.

How the two fit together:

* **One database, two roles.** The chat owns `chat_*`; it reads `users`,
  `user_settings` and `trainer_clients` read-only, through narrow SQL
  projections rather than shared entities.
* **Shared JWT secret.** The API issues tokens; the chat only verifies them.
* **Push stays in the API**, which holds the APNs/Firebase credentials — the
  chat asks over `POST /internal/push`, behind a shared secret. Keeping the
  Firebase SDK out of the chat's JVM is worth 64 MB of metaspace.
* **Clients learn the chat's URL at runtime** from `GET /api/v1/client-config`,
  so moving it needs no app release.

## Database

Technology:

* PostgreSQL (Neon serverless in production)

Schema migrations:

* Flyway

## Infrastructure

Development:

* Docker Compose

Components:

* Spring Boot
* PostgreSQL

Production:

* Backend: Render, Docker Web Service (HTTPS and reverse proxy provided by the platform)
* Database: Neon (serverless PostgreSQL)
* Web admin: Vercel

Runbooks live in `devops/` — see [deploy-backend-render.md](../devops/deploy-backend-render.md).

## API Style

REST API

JSON payloads

Versioned endpoints:

/api/v1/...

## Authentication

Phase 1:

* Single user mode

Phase 2:

* JWT authentication
* Multiple users

## Architecture Principles

* Domain driven structure
* Feature-based packages
* Separation of concerns
* Testability
* Scalability
