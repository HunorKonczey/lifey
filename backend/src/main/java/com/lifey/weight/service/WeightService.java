package com.lifey.weight.service;

import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public interface WeightService {

    List<WeightResponse> findAll();

    /**
     * Same as {@link #findAll()}, optionally bounded to a date range —
     * either or both of {@code from}/{@code to} may be null (no bound on that
     * side). Backs the `?from&to` query params on `GET /weights`.
     */
    List<WeightResponse> findAll(LocalDate from, LocalDate to);

    /**
     * Same as {@link #findAll(LocalDate, LocalDate)}, scoped to an explicit
     * user rather than the current one — used by the trainer client-weights
     * endpoint (see docs/personal_trainer/03-backend-terv.md). Callers are
     * responsible for authorizing {@code userId} first (e.g. via
     * {@code TrainerAccessService.requireActiveClient}).
     */
    List<WeightResponse> findAllForUser(Long userId, LocalDate from, LocalDate to);

    Page<WeightResponse> findDelta(Instant updatedSince, Pageable pageable);

    WeightResponse create(WeightRequest request);

    void delete(Long id);
}
