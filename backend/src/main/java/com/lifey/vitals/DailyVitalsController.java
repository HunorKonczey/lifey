package com.lifey.vitals;

import com.lifey.vitals.dto.DailyVitalsRequest;
import com.lifey.vitals.dto.DailyVitalsResponse;
import com.lifey.vitals.service.DailyVitalsService;
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
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

@Tag(name = "Daily Vitals", description = "Resting heart rate and HRV per day, imported from the health store")
@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/vitals")
public class DailyVitalsController {

    private final DailyVitalsService service;

    @Operation(summary = "List daily vitals (newest first)",
            description = "Optionally bounded to a date range via `from`/`to`; omit both for the full history.")
    @GetMapping(params = "!updatedSince")
    public List<DailyVitalsResponse> findAll(
            @Parameter(description = "Inclusive lower bound (yyyy-MM-dd); omit for no lower bound")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @Parameter(description = "Inclusive upper bound (yyyy-MM-dd); omit for no upper bound")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return from == null && to == null ? service.findAll() : service.findAll(from, to);
    }

    @Operation(summary = "Delta-sync feed of daily vitals",
            description = "Backs the mobile offline sync pull. Ordering is fixed to updatedAt,id ascending; a "
                    + "non-null `deletedAt` is a tombstone.")
    @GetMapping(params = "updatedSince")
    public Page<DailyVitalsResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant: switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return service.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Record the vitals of a day (upserts on date; both values are replaced)")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public DailyVitalsResponse create(@Valid @RequestBody DailyVitalsRequest request) {
        return service.create(request);
    }

    @Operation(summary = "Update the vitals of a day")
    @PutMapping("/{id}")
    public DailyVitalsResponse update(@PathVariable Long id, @Valid @RequestBody DailyVitalsRequest request) {
        return service.update(id, request);
    }

    @Operation(summary = "Delete the vitals of a day")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        service.delete(id);
    }
}
