package com.lifey.weight;

import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;

import java.util.List;

public interface WeightService {

    List<WeightResponse> findAll();

    WeightResponse create(WeightRequest request);

    void delete(Long id);
}
