package com.lifey.superadmin.dto;

import com.lifey.superadmin.RoleAuditAction;
import com.lifey.user.Role;

import java.time.Instant;

/** One entry of the global role-change feed ({@code GET /superadmin/role-audit}): who changed whose role, when. */
public record GlobalRoleAuditResponse(
        Long id,
        Long actorId,
        String actorName,
        String actorEmail,
        Long targetUserId,
        String targetName,
        String targetEmail,
        Role role,
        RoleAuditAction action,
        Instant createdAt
) {
}
