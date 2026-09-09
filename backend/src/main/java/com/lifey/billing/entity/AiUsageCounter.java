package com.lifey.billing.entity;

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

/**
 * One row per (user, calendar month) — how many AI calls that user has made
 * this month (docs/landing_page/64-billing-backend-plan.md §3.4, 63 D-M5).
 * Server-only bookkeeping, never synced to the mobile client, so this extends
 * {@link BaseEntity} rather than {@code SyncableEntity}.
 */
@Getter
@Setter
@Entity
@Table(name = "ai_usage_counter")
public class AiUsageCounter extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** {@code "yyyy-MM"}, matching {@link java.time.YearMonth#toString()}. */
    @Column(name = "year_month", nullable = false, length = 7)
    private String yearMonth;

    @Column(name = "used_count", nullable = false)
    private int usedCount;
}
