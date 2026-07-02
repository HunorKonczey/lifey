package com.lifey.workout.exercise;

import com.lifey.workout.exercise.dto.ExerciseRequest;
import com.lifey.workout.exercise.dto.ExerciseResponse;
import com.lifey.workout.exercise.service.ExerciseService;
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

@Tag(name = "Exercises", description = "Manage the exercise master list")
@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/exercises")
public class ExerciseController {

    private final ExerciseService exerciseService;

    @Operation(summary = "List all exercises (by name)")
    @GetMapping(params = "!updatedSince")
    public List<ExerciseResponse> findAll() {
        return exerciseService.findAll();
    }

    @Operation(summary = "Delta-sync feed of exercises",
            description = "Backs the mobile offline sync pull (see docs/16-delta-sync-rollout.md). "
                    + "`updatedSince` (ISO-8601 instant) is required; ordering is fixed to "
                    + "updatedAt,id ascending, and a non-null `deletedAt` on a returned row is a "
                    + "tombstone. Response is a standard Spring Data page.")
    @GetMapping(params = "updatedSince")
    public Page<ExerciseResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return exerciseService.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Get an exercise by id")
    @GetMapping("/{id}")
    public ExerciseResponse findById(@PathVariable Long id) {
        return exerciseService.findById(id);
    }

    @Operation(summary = "Create an exercise")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ExerciseResponse create(@Valid @RequestBody ExerciseRequest request) {
        return exerciseService.create(request);
    }

    @Operation(summary = "Update an exercise")
    @PutMapping("/{id}")
    public ExerciseResponse update(@PathVariable Long id, @Valid @RequestBody ExerciseRequest request) {
        return exerciseService.update(id, request);
    }

    @Operation(summary = "Delete an exercise (soft delete; the row is tombstoned, not removed)")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        exerciseService.delete(id);
    }
}
