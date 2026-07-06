package com.lifey.trainer;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * A trainer-client relationship — and, while {@link TrainerClientStatus#PENDING},
 * the invite itself (see docs/personal_trainer/02-domain-es-migraciok.md
 * "Változás 2"). Not delta-synced: this drives web-admin/mobile screens that
 * always hit the API directly, not offline-first data.
 */
@Getter
@Setter
@Entity
@Table(name = "trainer_clients")
public class TrainerClient extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trainer_id", nullable = false)
    private User trainer;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "client_id", nullable = false)
    private User client;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private TrainerClientStatus status;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "responded_at")
    private Instant respondedAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    /** Not mapped as a relation: purely an audit fact, read far less often than written. */
    @Column(name = "revoked_by")
    private Long revokedBy;

    /**
     * SHA-256 hash of the opaque token embedded in the invite email's accept/decline
     * links (see {@link com.lifey.trainer.service.TrainerInviteServiceImpl}); only set
     * while {@code lifey.trainer-invite.email-enabled} is on. Never store the raw token.
     */
    @Column(name = "email_token_hash", length = 64)
    private String emailTokenHash;
}
