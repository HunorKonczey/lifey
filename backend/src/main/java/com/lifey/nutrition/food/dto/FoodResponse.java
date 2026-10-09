package com.lifey.nutrition.food.dto;

import java.time.Instant;

public record FoodResponse(
        Long id,
        String name,
        Double caloriesPer100g,
        Double proteinPer100g,
        Double carbsPer100g,
        Double fatPer100g,
        String barcode,
        boolean hidden,
        // Delta-sync fields (docs/15-delta-sync.md) — updatedAt drives the
        // mobile cursor; deletedAt is non-null only for tombstoned rows.
        Instant updatedAt,
        Instant deletedAt,
        // Non-null only for a trainer-assigned copy (docs/personal_trainer/05-mobil-terv.md
        // §2) — drives the mobile "Edzőtől" badge.
        Long originTrainerId,
        // Dietary fibre and sugars per 100 g (LIF-145); null = not known.
        Double fiberPer100g,
        Double sugarPer100g
) {
    public FoodResponse(Long id, String name, Double caloriesPer100g, Double proteinPer100g, Double carbsPer100g,
                        Double fatPer100g, String barcode, boolean hidden, Instant updatedAt, Instant deletedAt,
                        Long originTrainerId) {
        this(id, name, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g, barcode, hidden, updatedAt,
                deletedAt, originTrainerId, null, null);
    }
}
