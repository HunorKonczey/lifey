package com.lifey.superadmin.dto;

import com.lifey.superadmin.RoleAuditAction;
import com.lifey.user.Role;

import java.time.Instant;

public record RoleAuditLogResponse(
        Long id,
        Long actorId,
        Role role,
        RoleAuditAction action,
        Instant createdAt
) {
}
