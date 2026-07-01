package com.lifey.workout.template;

import com.lifey.workout.template.dto.WorkoutTemplateRequest;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;
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

@Tag(name = "Workout Templates", description = "Reusable named lists of exercises")
@RestController
@RequestMapping("/api/v1/workout-templates")
public class WorkoutTemplateController {

    private final WorkoutTemplateService workoutTemplateService;

    public WorkoutTemplateController(WorkoutTemplateService workoutTemplateService) {
        this.workoutTemplateService = workoutTemplateService;
    }

    @Operation(summary = "List all workout templates")
    @GetMapping(params = "!updatedSince")
    public List<WorkoutTemplateResponse> findAll() {
        return workoutTemplateService.findAll();
    }

    @Operation(summary = "Delta-sync feed of workout templates",
            description = "Backs the mobile offline sync pull (see docs/16-delta-sync-rollout.md). "
                    + "`updatedSince` (ISO-8601 instant) is required; ordering is fixed to "
                    + "updatedAt,id ascending, and a non-null `deletedAt` on a returned row is a "
                    + "tombstone. Exercise links are not independently delta-synced — whenever a "
                    + "template appears here, replace all of its local exercise links. Response is "
                    + "a standard Spring Data page.")
    @GetMapping(params = "updatedSince")
    public Page<WorkoutTemplateResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return workoutTemplateService.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Get a workout template by id")
    @GetMapping("/{id}")
    public WorkoutTemplateResponse findById(@PathVariable Long id) {
        return workoutTemplateService.findById(id);
    }

    @Operation(summary = "Create a workout template")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public WorkoutTemplateResponse create(@Valid @RequestBody WorkoutTemplateRequest request) {
        return workoutTemplateService.create(request);
    }

    @Operation(summary = "Update a workout template (rename or change its exercises)")
    @PutMapping("/{id}")
    public WorkoutTemplateResponse update(@PathVariable Long id,
                                          @Valid @RequestBody WorkoutTemplateRequest request) {
        return workoutTemplateService.update(id, request);
    }

    @Operation(summary = "Delete a workout template")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        workoutTemplateService.delete(id);
    }
}
