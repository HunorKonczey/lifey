package com.lifey.workout.session.cardio.interval;

import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanRequest;
import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanResponse;
import com.lifey.workout.session.cardio.interval.service.CardioIntervalPlanService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@Tag(name = "Cardio Interval Plans", description = "Reusable interval plans for the indoor bike")
@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/cardio-interval-plans")
public class CardioIntervalPlanController {

    private final CardioIntervalPlanService cardioIntervalPlanService;

    @Operation(summary = "List all interval plans")
    @GetMapping(params = "!updatedSince")
    public List<CardioIntervalPlanResponse> findAll() {
        return cardioIntervalPlanService.findAll();
    }

    @Operation(summary = "Delta-sync feed of interval plans",
            description = "Backs the mobile offline sync pull (see docs/16-delta-sync-rollout.md). "
                    + "`updatedSince` (ISO-8601 instant) is required; ordering is fixed to "
                    + "updatedAt,id ascending, and a non-null `deletedAt` on a returned row is a "
                    + "tombstone. Steps are not independently delta-synced — whenever a plan "
                    + "appears here, replace all of its local steps. Response is a standard "
                    + "Spring Data page.")
    @GetMapping(params = "updatedSince")
    public Page<CardioIntervalPlanResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return cardioIntervalPlanService.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Get an interval plan by id")
    @GetMapping("/{id}")
    public CardioIntervalPlanResponse findById(@PathVariable Long id) {
        return cardioIntervalPlanService.findById(id);
    }

    @Operation(summary = "Create an interval plan")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CardioIntervalPlanResponse create(@Valid @RequestBody CardioIntervalPlanRequest request) {
        return cardioIntervalPlanService.create(request);
    }

    @Operation(summary = "Update an interval plan (rename or rebuild its steps)")
    @PutMapping("/{id}")
    public CardioIntervalPlanResponse update(@PathVariable Long id,
                                             @Valid @RequestBody CardioIntervalPlanRequest request) {
        return cardioIntervalPlanService.update(id, request);
    }

    @Operation(summary = "Delete an interval plan",
            description = "Soft delete. Sessions run with this plan are untouched — they carry "
                    + "their own executed sections (docs/cardio/60 D-C7.1).")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        cardioIntervalPlanService.delete(id);
    }
}
