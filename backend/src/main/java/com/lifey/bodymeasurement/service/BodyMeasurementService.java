package com.lifey.bodymeasurement.service;

import com.lifey.bodymeasurement.dto.BodyMeasurementRequest;
import com.lifey.bodymeasurement.dto.BodyMeasurementResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

/** Current-user body measurements (docs/80). Deliberately has no cross-user variant (§2.6). */
public interface BodyMeasurementService {

    List<BodyMeasurementResponse> findAll();

    Page<BodyMeasurementResponse> findDelta(Instant updatedSince, Pageable pageable);

    BodyMeasurementResponse create(BodyMeasurementRequest request);

    void delete(Long id);
}
