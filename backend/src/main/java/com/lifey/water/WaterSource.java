package com.lifey.water;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * A reusable water-intake preset (e.g. "Creatine Shake" = 0.9L), so logging a
 * habitual drink is a single tap instead of typing the volume every time.
 */
@Getter
@Setter
@Entity
@Table(name = "water_sources")
public class WaterSource extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private String name;

    @Column(name = "volume_liters", nullable = false)
    private double volumeLiters;
}
