# Lifey

Architecture:

- Frontend: Flutter
- Backend: Spring Boot 4 (Java 24)
- Database: PostgreSQL

Project structure:

- mobile/ = Flutter application
- backend/src/ = Spring Boot backend

Important rules:

- Never modify generated files.
- All business entities belong to a user.
- Authentication uses JWT + Refresh Tokens.
- Use Java 24.
- Use Maven.
- Prefer constructor injection.
- Use feature-based packaging.
- Do not introduce new frameworks without justification.
- Flyway migrations for database changes
- REST API only

Work tracking:

- Work is tracked in Jira: https://hunorkonczey.atlassian.net, project `LIF` (Lifey), cloudId `7c929810-cd27-408e-adb3-c1fd767f1e03`.
- Structure: Eposz (epic) → Story, all assigned to Hunor. Labels: `be`, `mobil`, `web`, `watch`, `chat`, `chat-be`, `trainer`, `cardio`, `billing`, `ai`, `sync`, `design`, `infra`, `store`.
- Starting a feature: find or create its Story under the matching epic and move it to Folyamatban (transition 21). Finished: Kész (41). Newly found follow-up work gets its own Story, not just a line in `docs/REMAINING-WORK.md`.
- The numbered plans in `docs/` still hold the design decisions; Jira holds status. Cite the plan number in the ticket description.

When implementing features, read only the files directly related to the task.
Do not scan the entire repository unless explicitly requested.