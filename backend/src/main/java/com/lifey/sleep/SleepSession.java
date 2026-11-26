package com.lifey.sleep;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * One sleep session from the health store: a night or a nap (docs/integrations/89 D-G7, {@code V98}).
 * <p>
 * The session belongs to the local date of its <em>end</em>, the wake-up date. Only the client knows the local time
 * zone, so it derives that date from {@link #endedAt}; there is no date column.
 * <p>
 * Imported values are measurements, so the API has no update. A session is created once and can only be deleted.
 */
@Getter
@Setter
@Entity
@Table(name = "sleep_sessions")
public class SleepSession extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "ended_at", nullable = false)
    private Instant endedAt;

    /** Time actually asleep, which can be less than the session's span. Null when the source didn't say. */
    @Column(name = "asleep_minutes")
    private Integer asleepMinutes;

    /** Stage minutes. Null, never 0, when the source records no stages (duration only). */
    @Column(name = "deep_minutes")
    private Integer deepMinutes;

    @Column(name = "light_minutes")
    private Integer lightMinutes;

    @Column(name = "rem_minutes")
    private Integer remMinutes;

    @Column(name = "awake_minutes")
    private Integer awakeMinutes;

    /** The app the health store reported as the writer, e.g. "Garmin Connect". Null when it reported none. */
    @Column(name = "source_app_name", length = 64)
    private String sourceAppName;

    /** The store's record id, the import dedupe key: unique per user, soft-deleted rows included. */
    @Column(name = "health_record_id", length = 128)
    private String healthRecordId;
}
