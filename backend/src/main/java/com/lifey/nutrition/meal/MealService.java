package com.lifey.nutrition.meal;

import com.lifey.nutrition.meal.dto.MealRequest;
import com.lifey.nutrition.meal.dto.MealResponse;

import java.util.List;

public interface MealService {

    List<MealResponse> findAll();

    MealResponse create(MealRequest request);

    MealResponse update(Long id, MealRequest request);

    void delete(Long id);
}
