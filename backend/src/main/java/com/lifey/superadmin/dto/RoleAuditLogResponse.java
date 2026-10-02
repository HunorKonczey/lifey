package com.lifey.superadmin.dto;

import com.lifey.superadmin.RoleAuditAction;
import com.lifey.user.Role;

import java.time.Instant;

/** One role change of a user ({@code GET /superadmin/users/{id}/role-audit}); the actor's name is null when they have no profile name. */
public record RoleAuditLogResponse(
        Long id,
        Long actorId,
        String actorName,
        String actorEmail,
        Role role,
        RoleAuditAction action,
        Instant createdAt
) {
}
