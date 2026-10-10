package com.lifey.nutrition.food;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.BatchSize;

import java.util.ArrayList;
import java.util.List;

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

    /** Dietary fibre and sugars per 100 g (LIF-145); null = not known, which is not zero. */
    @Column(name = "fiber_per_100g")
    private Double fiberPer100g;

    @Column(name = "sugar_per_100g")
    private Double sugarPer100g;

    /**
     * Named serving sizes (LIF-146), in the order the owner gave them. Lazy and batch-fetched: a page of foods is one extra query
     * for all their servings, not one per food.
     */
    @ElementCollection(fetch = FetchType.LAZY)
    @CollectionTable(name = "food_servings", joinColumns = @JoinColumn(name = "food_id"))
    @OrderColumn(name = "position")
    @BatchSize(size = 100)
    private List<FoodServing> servings = new ArrayList<>();

    @Column(name = "barcode")
    private String barcode;

    @Column(nullable = false)
    private boolean hidden;

    /** The owner's favourite mark (LIF-147), separate from the one on recipes. */
    @Column(nullable = false)
    private boolean favorite;

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
