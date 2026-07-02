package com.lifey.nutrition.food.service;

import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface FoodService {

    List<FoodResponse> findAll();

    /**
     * Paged variant backing GET /api/v1/foods?page=... . When {@code
     * updatedSince} is non-null, this is a delta-sync request (see
     * docs/15-delta-sync.md): {@code search} is ignored, hidden/tombstoned
     * rows are included, and results are always ordered by
     * {@code updatedAt, id} ascending regardless of the requested
     * {@code Pageable}'s sort. Otherwise, when {@code search} is non-blank,
     * results are additionally filtered by a case-insensitive name
     * contains-match; hidden foods are excluded either way.
     */
    Page<FoodResponse> findPage(Pageable pageable, String search, Instant updatedSince);

    FoodResponse findById(Long id);

    FoodResponse create(FoodRequest request);

    FoodResponse update(Long id, FoodRequest request);

    void delete(Long id);
}
