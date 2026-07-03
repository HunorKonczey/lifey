package com.lifey.weight.service;

import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface WeightService {

    List<WeightResponse> findAll();

    /**
     * Same as {@link #findAll()}, scoped to an explicit user rather than the
     * current one — used by the trainer client-weights endpoint (see
     * docs/personal_trainer/03-backend-terv.md). Callers are responsible for
     * authorizing {@code userId} first (e.g. via
     * {@code TrainerAccessService.requireActiveClient}).
     */
    List<WeightResponse> findAllForUser(Long userId);

    Page<WeightResponse> findDelta(Instant updatedSince, Pageable pageable);

    WeightResponse create(WeightRequest request);

    void delete(Long id);
}
