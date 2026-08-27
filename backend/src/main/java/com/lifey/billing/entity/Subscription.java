package com.lifey.billing.entity;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * One row per (user, provider) pair — the local mirror of what Stripe or a
 * store says a user is entitled to (docs/landing_page/64-billing-backend-plan.md
 * D-B1). Not delta-synced: entitlement is derived server-side and never
 * cached offline (D-B3).
 *
 * <p>Only {@code SubscriptionWriter} may write this table (D-B2) — everything
 * else, including this entity's own getters, is read-only from the outside.
 */
@Getter
@Setter
@Entity
@Table(name = "subscription")
public class Subscription extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private SubscriptionProvider provider;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private SubscriptionStatus status;

    /** Trainer subscriptions only; null for a plain Pro subscription. */
    @Enumerated(EnumType.STRING)
    @Column(length = 16)
    private TrainerPlan plan;

    @Column(name = "provider_customer_id")
    private String providerCustomerId;

    /**
     * The Stripe subscription id, the Apple {@code originalTransactionId}, or
     * the Play purchase token's linked subscription id — the purchase
     * identity, not the receipt (D-B6). Unique where not null.
     */
    @Column(name = "provider_subscription_id")
    private String providerSubscriptionId;

    @Column(name = "current_period_end")
    private Instant currentPeriodEnd;

    @Column(name = "trial_ends_at")
    private Instant trialEndsAt;

    @Column(name = "cancel_at_period_end", nullable = false)
    private boolean cancelAtPeriodEnd;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
