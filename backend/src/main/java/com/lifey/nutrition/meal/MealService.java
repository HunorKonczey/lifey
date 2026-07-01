package com.lifey.nutrition.meal;

import com.lifey.nutrition.meal.dto.MealRequest;
import com.lifey.nutrition.meal.dto.MealResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface MealService {

    List<MealResponse> findAll();

    Page<MealResponse> findDelta(Instant updatedSince, Pageable pageable);

    MealResponse create(MealRequest request);

    MealResponse update(Long id, MealRequest request);

    void delete(Long id);
}
