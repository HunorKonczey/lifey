package com.lifey.nutrition.food.service;

import com.lifey.nutrition.food.dto.BarcodeLookupResponse;

public interface BarcodeLookupService {

    /**
     * @throws com.lifey.common.exception.ResourceNotFoundException if there's no
     *                                                              existing {@code Food} for the barcode and OpenFoodFacts has no usable
     *                                                              nutrition data for it either
     */
    BarcodeLookupResponse lookup(String barcode);
}
