package com.lifey.steps;

import com.lifey.steps.dto.DailyStepCountRequest;
import com.lifey.steps.dto.DailyStepCountResponse;
import com.lifey.steps.service.DailyStepCountService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

@Tag(name = "Step Tracking", description = "Persisted daily step counts")
@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/steps")
public class DailyStepCountController {

    private final DailyStepCountService stepCountService;

    @Operation(summary = "List daily step counts (newest first)",
            description = "Optionally bounded to a date range via `from`/`to` (either or both may "
                    + "be omitted); omit both for the full history.")
    @GetMapping(params = "!updatedSince")
    public List<DailyStepCountResponse> findAll(
            @Parameter(description = "Inclusive lower bound (yyyy-MM-dd); omit for no lower bound")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @Parameter(description = "Inclusive upper bound (yyyy-MM-dd); omit for no upper bound")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return from == null && to == null ? stepCountService.findAll() : stepCountService.findAll(from, to);
    }

    @Operation(summary = "Delta-sync feed of daily step counts",
            description = "Backs the mobile offline sync pull (see docs/16-delta-sync-rollout.md). "
                    + "`updatedSince` (ISO-8601 instant) is required; ordering is fixed to "
                    + "updatedAt,id ascending, and a non-null `deletedAt` on a returned row is a "
                    + "tombstone. Response is a standard Spring Data page.")
    @GetMapping(params = "updatedSince")
    public Page<DailyStepCountResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return stepCountService.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Record a daily step count (upserts on date)")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public DailyStepCountResponse create(@Valid @RequestBody DailyStepCountRequest request) {
        return stepCountService.create(request);
    }

    @Operation(summary = "Update a daily step count")
    @PutMapping("/{id}")
    public DailyStepCountResponse update(@PathVariable Long id, @Valid @RequestBody DailyStepCountRequest request) {
        return stepCountService.update(id, request);
    }

    @Operation(summary = "Delete a daily step count")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        stepCountService.delete(id);
    }
}
