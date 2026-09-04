package com.lifey.billing.entity;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * Idempotency ledger for webhook/notification delivery (docs/landing_page/64-billing-backend-plan.md
 * §5.4). A duplicate {@code (provider, eventId)} insert is what makes a
 * replayed Stripe event or Play RTDN a no-op instead of a double-applied
 * subscription change.
 */
@Getter
@Setter
@Entity
@Table(name = "processed_billing_event")
public class ProcessedBillingEvent extends BaseEntity {

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private SubscriptionProvider provider;

    @Column(name = "event_id", nullable = false)
    private String eventId;

    @Column(name = "event_type", nullable = false, length = 64)
    private String eventType;

    @Column(name = "processed_at", nullable = false)
    private Instant processedAt;

    @PrePersist
    void onCreate() {
        if (processedAt == null) {
            processedAt = Instant.now();
        }
    }
}
