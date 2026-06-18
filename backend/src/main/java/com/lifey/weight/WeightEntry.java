package com.lifey.weight;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "weight_entries")
public class WeightEntry extends BaseEntity {

    @Column(name = "entry_date", nullable = false)
    private LocalDate date;

    /**
     * The instant the entry was recorded. Stamped by the server on creation and used
     * to break ties between entries sharing the same {@link #date} (newest first).
     */
    @Column(name = "recorded_at", nullable = false)
    private Instant recordedAt;

    @Column(nullable = false)
    private double weight;
}
