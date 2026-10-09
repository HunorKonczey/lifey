package com.lifey.trainer.entity;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * A shareable join link a trainer hands out (LIF-103). Unlike an email invite ({@link TrainerClient} while PENDING) it
 * is not bound to an account until somebody redeems it; redeeming creates the ordinary ACTIVE relationship. Single-use
 * and short-lived. Only the token's hash is stored — the token itself is shown once, when the link is made.
 */
@Getter
@Setter
@Entity
@Table(name = "trainer_invite_links")
public class TrainerInviteLink extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trainer_id", nullable = false)
    private User trainer;

    @Column(name = "token_hash", nullable = false, length = 64)
    private String tokenHash;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "redeemed_at")
    private Instant redeemedAt;

    /** Plain id, not a relation: an audit fact about who used the link. */
    @Column(name = "redeemed_by")
    private Long redeemedBy;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    /** Usable right now: not redeemed, not revoked, not past its expiry. */
    public boolean isLive(Instant now) {
        return redeemedAt == null && revokedAt == null && expiresAt.isAfter(now);
    }
}
