package com.lifey.steps;

import com.lifey.steps.dto.DailyStepCountRequest;
import com.lifey.steps.dto.DailyStepCountResponse;

import java.util.List;

public interface DailyStepCountService {

    List<DailyStepCountResponse> findAll();

    DailyStepCountResponse create(DailyStepCountRequest request);

    DailyStepCountResponse update(Long id, DailyStepCountRequest request);

    void delete(Long id);
}
