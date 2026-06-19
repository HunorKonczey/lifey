package com.lifey.water;

import com.lifey.water.dto.WaterEntryRequest;
import com.lifey.water.dto.WaterEntryResponse;

import java.util.List;

public interface WaterEntryService {

    List<WaterEntryResponse> findAll();

    WaterEntryResponse create(WaterEntryRequest request);

    void delete(Long id);
}
