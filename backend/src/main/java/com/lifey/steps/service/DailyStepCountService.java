package com.lifey.steps.service;

import com.lifey.steps.dto.DailyStepCountRequest;
import com.lifey.steps.dto.DailyStepCountResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface DailyStepCountService {

    List<DailyStepCountResponse> findAll();

    /**
     * Same as {@link #findAll()}, scoped to an explicit user rather than the
     * current one — used by the trainer client-steps endpoint (see
     * docs/personal_trainer/03-backend-terv.md). Callers are responsible for
     * authorizing {@code userId} first (e.g. via
     * {@code TrainerAccessService.requireActiveClient}).
     */
    List<DailyStepCountResponse> findAllForUser(Long userId);

    Page<DailyStepCountResponse> findDelta(Instant updatedSince, Pageable pageable);

    DailyStepCountResponse create(DailyStepCountRequest request);

    DailyStepCountResponse update(Long id, DailyStepCountRequest request);

    void delete(Long id);
}
