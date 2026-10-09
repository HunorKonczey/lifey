package com.lifey.weight;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "weight_entries")
public class WeightEntry extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "entry_date", nullable = false)
    private LocalDate date;

    /**
     * The instant the entry was recorded - the client's own time when it sends one (never later than the
     * server's now), else stamped by the server on creation. Also breaks ties between entries sharing the same
     * {@link #date} (newest first).
     */
    @Column(name = "recorded_at", nullable = false)
    private Instant recordedAt;

    @Column(nullable = false)
    private double weight;

    /** Optional free text about the weigh-in (LIF-115), at most 280 characters; null when none. */
    @Column(length = 280)
    private String note;
}
