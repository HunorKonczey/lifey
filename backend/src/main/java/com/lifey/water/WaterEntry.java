package com.lifey.water;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * A logged water intake event. {@link #volumeLiters} is a snapshot taken at
 * creation time (copied from the {@link WaterSource} if one was used) so
 * editing or deleting a source later never changes past entries — the FK is
 * {@code on delete set null} for the same reason, purely informational.
 */
@Getter
@Setter
@Entity
@Table(name = "water_entries")
public class WaterEntry extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "water_source_id")
    private WaterSource waterSource;

    @Column(name = "volume_liters", nullable = false)
    private double volumeLiters;

    @Column(name = "consumed_at", nullable = false)
    private Instant consumedAt;
}
