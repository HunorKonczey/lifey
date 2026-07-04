package com.lifey.steps.service;

import com.lifey.steps.dto.DailyStepCountRequest;
import com.lifey.steps.dto.DailyStepCountResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public interface DailyStepCountService {

    List<DailyStepCountResponse> findAll();

    /**
     * Same as {@link #findAll()}, optionally bounded to a date range —
     * either or both of {@code from}/{@code to} may be null (no bound on that
     * side). Backs the `?from&to` query params on `GET /steps`.
     */
    List<DailyStepCountResponse> findAll(LocalDate from, LocalDate to);

    /**
     * Same as {@link #findAll(LocalDate, LocalDate)}, scoped to an explicit
     * user rather than the current one — used by the trainer client-steps
     * endpoint (see docs/personal_trainer/03-backend-terv.md). Callers are
     * responsible for authorizing {@code userId} first (e.g. via
     * {@code TrainerAccessService.requireActiveClient}).
     */
    List<DailyStepCountResponse> findAllForUser(Long userId, LocalDate from, LocalDate to);

    Page<DailyStepCountResponse> findDelta(Instant updatedSince, Pageable pageable);

    DailyStepCountResponse create(DailyStepCountRequest request);

    DailyStepCountResponse update(Long id, DailyStepCountRequest request);

    void delete(Long id);
}
