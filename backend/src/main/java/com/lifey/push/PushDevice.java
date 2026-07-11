package com.lifey.push;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * A registered device push token (docs/30-push-notifications-plan.md, B1).
 * Not delta-synced to mobile — this is server-only bookkeeping — so it
 * extends {@link BaseEntity} directly rather than {@code SyncableEntity}.
 * {@link #deletedAt} is set on logout or when the push provider reports the
 * token as no longer valid.
 */
@Getter
@Setter
@Entity
@Table(name = "push_devices")
public class PushDevice extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PushPlatform platform;

    @Column(nullable = false, unique = true, length = 200)
    private String token;

    @Column(name = "last_registered_at", nullable = false)
    private Instant lastRegisteredAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;
}
