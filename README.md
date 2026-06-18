# Lifey — Fitness & Nutrition Tracker

Monorepo for the Lifey personal fitness and nutrition tracker.

## Structure

- `mobile/` — Flutter app (Riverpod, GoRouter, Dio, Isar), feature-based layers.
- `backend/` — Spring Boot 4 / Java 24 REST API, domain-driven feature packages, Flyway migrations.
- `docs/` — Product vision, architecture, domain model, and requirements.
- `docker-compose.yml` — PostgreSQL + backend for local development.

## Getting started

```bash
docker compose up        # start PostgreSQL + backend
cd mobile && flutter run # run the mobile app
```

> Scaffolding only — business logic is not implemented yet.
