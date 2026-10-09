package com.lifey.common.job;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * The state of a job that has to run once per database (V90, LIF-149): where it got to ({@code cursorId}), who is running it
 * ({@code claimedUntil}, a lease) and whether it is over ({@code completedAt}). Not a business entity - it belongs to no user
 * and is only ever written through {@link OneTimeJobRepository}'s guarded updates.
 */
@Getter
@Setter
@Entity
@Table(name = "one_time_jobs")
public class OneTimeJob {

    @Id
    @Column(length = 100)
    private String name;

    @Column(name = "cursor_id", nullable = false)
    private long cursorId;

    @Column(name = "claimed_until")
    private Instant claimedUntil;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "processed_count", nullable = false)
    private int processedCount;

    @Column(name = "filled_count", nullable = false)
    private int filledCount;

    public boolean isCompleted() {
        return completedAt != null;
    }
}
