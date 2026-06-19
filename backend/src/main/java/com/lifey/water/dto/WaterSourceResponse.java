package com.lifey.water.dto;

public record WaterSourceResponse(
        Long id,
        String name,
        Double volumeLiters
) {
}
