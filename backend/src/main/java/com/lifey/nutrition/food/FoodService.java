package com.lifey.nutrition.food;

import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;

import java.util.List;

public interface FoodService {

    List<FoodResponse> findAll();

    FoodResponse findById(Long id);

    FoodResponse create(FoodRequest request);

    FoodResponse update(Long id, FoodRequest request);

    void delete(Long id);
}
