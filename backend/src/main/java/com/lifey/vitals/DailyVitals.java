package com.lifey.vitals;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

/**
 * One day of vitals from the health store: resting heart rate and heart rate variability (docs/integrations/89
 * D-G8, {@code V100}). One row per user per day, like {@link com.lifey.steps.DailyStepCount}.
 * <p>
 * Either value may be missing, never both. {@link #hrvMethod} is set exactly when {@link #hrvMs} is.
 */
@Getter
@Setter
@Entity
@Table(
        name = "daily_vitals",
        uniqueConstraints = @UniqueConstraint(
                name = "daily_vitals_user_id_entry_date_unique",
                columnNames = {"user_id", "entry_date"}
        )
)
public class DailyVitals extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "entry_date", nullable = false)
    private LocalDate date;

    /** Resting heart rate in bpm. */
    @Column(name = "resting_hr")
    private Integer restingHr;

    /** Heart rate variability in milliseconds, measured by {@link #hrvMethod}. */
    @Column(name = "hrv_ms")
    private Double hrvMs;

    @Enumerated(EnumType.STRING)
    @Column(name = "hrv_method", length = 8)
    private HrvMethod hrvMethod;
}
