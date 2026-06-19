# Authentication Module Implementation

Based on the previously discussed Lifey architecture, design and implement the authentication module only.

Do not redesign the overall project structure. Assume the existing architecture decisions remain unchanged.

Focus exclusively on authentication, authorization, JWT handling, refresh token management, security configuration, and user identity handling.

## Requirements

### Authentication Strategy

Implement:

* Spring Security 6
* JWT Access Tokens
* Refresh Tokens stored in database
* Stateless authentication
* BCrypt password hashing

Do not use:

* OAuth
* Keycloak
* Supabase Auth
* External identity providers

This should be a fully custom authentication implementation.

---

## User Authentication Flow

### Registration

Endpoint:

```http
POST /api/auth/register
```

Requirements:

* Unique email validation
* Password hashing using BCrypt
* Automatic ROLE_USER assignment
* Return created user DTO

---

### Login

Endpoint:

```http
POST /api/auth/login
```

Requirements:

* Validate credentials
* Generate Access Token
* Generate Refresh Token
* Store Refresh Token in database
* Return token pair

Access Token lifetime:

```text
15 minutes
```

Refresh Token lifetime:

```text
30 days
```

---

### Refresh Token

Endpoint:

```http
POST /api/auth/refresh
```

Requirements:

* Validate refresh token
* Verify token is not revoked
* Verify token is not expired
* Revoke old refresh token
* Issue new refresh token
* Issue new access token

Implement refresh token rotation.

---

### Logout

Endpoint:

```http
POST /api/auth/logout
```

Requirements:

* Revoke refresh token
* User becomes logged out

---

## User Identity

I want a reusable mechanism for accessing the authenticated user.

I do not want controllers manually parsing SecurityContext everywhere.

Design a clean solution such as:

```java
currentUserProvider.getUserId()
```

or

```java
@CurrentUser UserPrincipal principal
```

Explain which approach is preferable and why.

---

## JWT Design

Token should contain:

```json
{
  "sub": "userId",
  "email": "user@example.com",
  "roles": [
    "ROLE_USER"
  ]
}
```

Do not include sensitive information.

Provide:

* JwtService
* JwtAuthenticationFilter
* JwtProperties
* Token generation
* Token validation
* Claims extraction

---

## Spring Security Configuration

Public:

```text
/api/auth/register
/api/auth/login
/api/auth/refresh
```

Protected:

```text
/api/**
```

Requirements:

* Stateless
* No sessions
* JWT filter
* Clean SecurityFilterChain configuration

Use Spring Boot 3 and modern Spring Security practices.

Avoid deprecated APIs.

---

## Refresh Token Persistence

Design a RefreshToken entity.

Requirements:

* UUID identifier
* User reference
* Expiration date
* Revocation flag
* Future support for multiple devices

I want the design to support:

* logout from current device
* logout from all devices
* password reset invalidating all sessions

without major refactoring later.

---

## Authorization

Current roles:

```text
ROLE_USER
ROLE_ADMIN
```

Every new user gets:

```text
ROLE_USER
```

Design role handling so it can be extended later.

---

## Error Handling

Provide authentication-related exception handling for:

* Invalid credentials
* Expired access token
* Expired refresh token
* Revoked refresh token
* Missing token
* Invalid token
* Access denied

Return consistent API responses.

---

## Deliverables

Provide:

1. Recommended package structure for auth module
2. Entity definitions
3. DTOs
4. Security configuration
5. JWT implementation
6. Refresh token implementation
7. Authentication service
8. Authentication controller
9. Exception handling
10. Database schema
11. Authentication sequence diagrams
12. Security considerations
13. Common mistakes to avoid
14. Future-proofing recommendations

Do not generate placeholder code.

Provide production-grade implementation recommendations and explain the reasoning behind architectural decisions.
FYI: All business entities in the application must belong to a specific user.

The authenticated user must always be resolved from the JWT/security context.

Controllers must never accept userId as request input.

Bad:

GET /users/{userId}/weights

Good:

GET /weights

The backend should automatically determine the current authenticated user.

Design the authentication module with this ownership model in mind and recommend the most appropriate implementation approach for JPA and PostgreSQL.