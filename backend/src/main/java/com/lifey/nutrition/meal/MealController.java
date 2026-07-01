package com.lifey.nutrition.meal;

import com.lifey.nutrition.meal.dto.MealRequest;
import com.lifey.nutrition.meal.dto.MealResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
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
import java.util.List;

@Tag(name = "Meals", description = "Log meals with food entries")
@RestController
@RequestMapping("/api/v1/meals")
public class MealController {

    private final MealService mealService;

    public MealController(MealService mealService) {
        this.mealService = mealService;
    }

    @Operation(summary = "List all meals (newest first)")
    @GetMapping(params = "!updatedSince")
    public List<MealResponse> findAll() {
        return mealService.findAll();
    }

    @Operation(summary = "Delta-sync feed of meals",
            description = "Backs the mobile offline sync pull (see docs/16-delta-sync-rollout.md). "
                    + "`updatedSince` (ISO-8601 instant) is required; ordering is fixed to "
                    + "updatedAt,id ascending, and a non-null `deletedAt` on a returned row is a "
                    + "tombstone. Entries are not independently delta-synced — whenever a meal "
                    + "appears here, replace all of its local entries. Response is a standard "
                    + "Spring Data page.")
    @GetMapping(params = "updatedSince")
    public Page<MealResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return mealService.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Log a meal")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public MealResponse create(@Valid @RequestBody MealRequest request) {
        return mealService.create(request);
    }

    @Operation(summary = "Update a meal")
    @PutMapping("/{id}")
    public MealResponse update(@PathVariable Long id, @Valid @RequestBody MealRequest request) {
        return mealService.update(id, request);
    }

    @Operation(summary = "Delete a meal")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        mealService.delete(id);
    }
}
