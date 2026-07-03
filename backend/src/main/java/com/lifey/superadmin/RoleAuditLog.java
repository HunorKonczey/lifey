package com.lifey.superadmin;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.Role;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * Append-only record of a role grant/revoke (docs/personal_trainer/
 * 02-domain-es-migraciok.md, "Változás 4"). Actor/target are plain ids, not
 * mapped relations — an audit log is written far more than it's read, and
 * when it is read it's always by {@code targetUserId} (see
 * {@link RoleAuditLogRepository}), never joined through the user graph.
 */
@Getter
@Setter
@Entity
@Table(name = "role_audit_log")
public class RoleAuditLog extends BaseEntity {

    @Column(name = "actor_id", nullable = false)
    private Long actorId;

    @Column(name = "target_user_id", nullable = false)
    private Long targetUserId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private Role role;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private RoleAuditAction action;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
}
