package com.lifey.workout.session.cardio.interval.service;

import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanRequest;
import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface CardioIntervalPlanService {

    List<CardioIntervalPlanResponse> findAll();

    Page<CardioIntervalPlanResponse> findDelta(Instant updatedSince, Pageable pageable);

    CardioIntervalPlanResponse findById(Long id);

    CardioIntervalPlanResponse create(CardioIntervalPlanRequest request);

    CardioIntervalPlanResponse update(Long id, CardioIntervalPlanRequest request);

    void delete(Long id);
}
