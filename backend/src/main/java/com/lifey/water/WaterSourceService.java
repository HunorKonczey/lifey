package com.lifey.water;

import com.lifey.water.dto.WaterSourceRequest;
import com.lifey.water.dto.WaterSourceResponse;

import java.util.List;

public interface WaterSourceService {

    List<WaterSourceResponse> findAll();

    WaterSourceResponse findById(Long id);

    WaterSourceResponse create(WaterSourceRequest request);

    WaterSourceResponse update(Long id, WaterSourceRequest request);

    void delete(Long id);
}
