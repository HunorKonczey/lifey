package com.lifey.nutrition.food;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "foods")
public class Food extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

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
     * Provenance for a copy created by the trainer content-assignment feature
     * (docs/personal_trainer/02-domain-es-migraciok.md, "Változás 3") — null for
     * every food a user created themselves. Not an FK: the trainer's original may
     * be soft-deleted later without invalidating the client's copy.
     */
    @Column(name = "origin_source_id")
    private Long originSourceId;

    @Column(name = "origin_trainer_id")
    private Long originTrainerId;
}
