package com.lifey.bodymeasurement;

import com.lifey.bodymeasurement.dto.BodyMeasurementRequest;
import com.lifey.bodymeasurement.dto.BodyMeasurementResponse;
import com.lifey.bodymeasurement.service.BodyMeasurementService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.List;

@Tag(name = "Body Measurements", description = "Waist, chest, hips, arm and thigh measurements in cm")
@RestController
@RequestMapping("/api/v1/measurements")
@RequiredArgsConstructor
public class BodyMeasurementController {

    private final BodyMeasurementService service;

    @Operation(summary = "List body measurements (newest first)")
    @GetMapping(params = "!updatedSince")
    public List<BodyMeasurementResponse> findAll() {
        return service.findAll();
    }

    @Operation(summary = "Delta-sync feed of body measurements",
            description = "Backs the mobile offline sync pull (docs/16-delta-sync-rollout.md). "
                    + "`updatedSince` is required; ordering is fixed to updatedAt,id ascending and a "
                    + "non-null `deletedAt` on a returned row is a tombstone.")
    @GetMapping(params = "updatedSince")
    public Page<BodyMeasurementResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return service.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Add a body measurement")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public BodyMeasurementResponse create(@Valid @RequestBody BodyMeasurementRequest request) {
        return service.create(request);
    }

    @Operation(summary = "Delete a body measurement")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        service.delete(id);
    }
}
