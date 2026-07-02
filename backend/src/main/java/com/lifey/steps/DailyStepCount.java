package com.lifey.steps;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(
        name = "daily_step_counts",
        uniqueConstraints = @UniqueConstraint(
                name = "daily_step_counts_user_id_entry_date_key",
                columnNames = {"user_id", "entry_date"}
        )
)
public class DailyStepCount extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "entry_date", nullable = false)
    private LocalDate date;

    @Column(nullable = false)
    private int steps;
}
