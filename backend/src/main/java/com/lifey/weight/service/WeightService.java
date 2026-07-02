package com.lifey.weight.service;

import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface WeightService {

    List<WeightResponse> findAll();

    Page<WeightResponse> findDelta(Instant updatedSince, Pageable pageable);

    WeightResponse create(WeightRequest request);

    void delete(Long id);
}
