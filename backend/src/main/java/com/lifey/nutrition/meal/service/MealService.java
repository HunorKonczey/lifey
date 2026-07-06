package com.lifey.nutrition.meal.service;

import com.lifey.nutrition.meal.dto.MealRequest;
import com.lifey.nutrition.meal.dto.MealResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public interface MealService {

    List<MealResponse> findAll();

    /**
     * Read-only lookup of another user's meals, bounded to a date range —
     * backs the trainer dashboard (docs/personal_trainer/03-backend-terv.md).
     * Either bound may be null for an open end.
     */
    List<MealResponse> findAllForUserBetween(Long userId, LocalDate from, LocalDate to);

    Page<MealResponse> findDelta(Instant updatedSince, Pageable pageable);

    MealResponse create(MealRequest request);

    MealResponse update(Long id, MealRequest request);

    void delete(Long id);
}
