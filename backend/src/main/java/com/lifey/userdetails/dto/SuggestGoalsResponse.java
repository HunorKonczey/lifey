package com.lifey.userdetails.dto;

public record SuggestGoalsResponse(
        int bmr,
        int tdee,
        int calories,
        int proteinGrams,
        int carbsGrams,
        int fatGrams,
        double waterLiters
) {
}
