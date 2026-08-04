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
