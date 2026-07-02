package com.lifey.water.service;

import com.lifey.water.dto.WaterEntryRequest;
import com.lifey.water.dto.WaterEntryResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface WaterEntryService {

    List<WaterEntryResponse> findAll();

    Page<WaterEntryResponse> findDelta(Instant updatedSince, Pageable pageable);

    WaterEntryResponse create(WaterEntryRequest request);

    void delete(Long id);
}
