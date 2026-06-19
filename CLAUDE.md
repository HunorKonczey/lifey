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
- Use Java 21.
- Use Maven.
- Prefer constructor injection.
- Use feature-based packaging.
- Do not introduce new frameworks without justification.
- Flyway migrations for database changes
- REST API only

When implementing features, read only the files directly related to the task.
Do not scan the entire repository unless explicitly requested.