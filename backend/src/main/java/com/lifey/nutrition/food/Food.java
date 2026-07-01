package com.lifey.nutrition.food;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "foods")
public class Food extends BaseEntity {

    @Column(nullable = false)
    private String name;

    @Column(name = "calories_per_100g", nullable = false)
    private double caloriesPer100g;

    @Column(name = "protein_per_100g", nullable = false)
    private double proteinPer100g;

    @Column(name = "carbs_per_100g")
    private Double carbsPer100g;

    @Column(name = "fat_per_100g")
    private Double fatPer100g;

    @Column(name = "barcode")
    private String barcode;

    @Column(nullable = false)
    private boolean hidden;

    /**
     * Drives the mobile delta-sync pull (see docs/15-delta-sync.md) — bumped
     * on every insert/update by the lifecycle callbacks below rather than a
     * DB trigger, since every write to this entity already goes through JPA.
     */
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /**
     * Tombstone for delta sync, set only by {@link FoodServiceImpl#delete}.
     * Deliberately separate from {@code hidden}, which is also used for
     * quick-macro shadow foods that were never deleted.
     */
    @Column(name = "deleted_at")
    private Instant deletedAt;

    @PrePersist
    protected void onCreate() {
        updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}
