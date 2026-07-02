package com.lifey.steps.service;

import com.lifey.steps.dto.DailyStepCountRequest;
import com.lifey.steps.dto.DailyStepCountResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface DailyStepCountService {

    List<DailyStepCountResponse> findAll();

    Page<DailyStepCountResponse> findDelta(Instant updatedSince, Pageable pageable);

    DailyStepCountResponse create(DailyStepCountRequest request);

    DailyStepCountResponse update(Long id, DailyStepCountRequest request);

    void delete(Long id);
}
