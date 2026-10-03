package com.lifey.superadmin.dto;

import java.time.Instant;
import java.util.Set;

/**
 * One row of {@code GET /api/v1/superadmin/users}. {@code trainerName} is the display name of the user's active
 * trainer (a client) and {@code clientCount} the number of active clients (a trainer) — each null when it does not
 * apply. Names are null when the user never filled in their profile. {@code lastActiveAt} is the last authenticated
 * request (docs/redesign-web/82 section 2.3), null until the user's first request after the column was added.
 */
public record SuperAdminUserResponse(
        Long id,
        String email,
        Set<String> roles,
        Instant createdAt,
        boolean hasAvatar,
        String firstName,
        String lastName,
        String trainerName,
        Integer clientCount,
        Instant lastActiveAt
) {
}
