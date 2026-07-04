package com.lifey.workout.session;

import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import com.lifey.workout.session.service.WorkoutSessionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@Tag(name = "Workout Sessions", description = "Logged workouts with sets, reps and weight")
@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/workout-sessions")
public class WorkoutSessionController {

    private final WorkoutSessionService workoutSessionService;

    @Operation(summary = "List all workout sessions (newest first)")
    @GetMapping(params = {"!updatedSince", "!page"})
    public List<WorkoutSessionResponse> findAll() {
        return workoutSessionService.findAll();
    }

    @Operation(summary = "List workout sessions, paged (newest first)",
            description = "An additive alternative to the unpaged list, for callers that want to "
                    + "page through a long history instead of pulling everything at once.")
    @GetMapping(params = {"!updatedSince", "page"})
    public Page<WorkoutSessionResponse> findPage(
            @PageableDefault(size = 20, sort = "startedAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return workoutSessionService.findPage(pageable);
    }

    @Operation(summary = "Delta-sync feed of workout sessions",
            description = "Backs the mobile offline sync pull (see docs/16-delta-sync-rollout.md). "
                    + "`updatedSince` (ISO-8601 instant) is required; ordering is fixed to "
                    + "updatedAt,id ascending, and a non-null `deletedAt` on a returned row is a "
                    + "tombstone. Sets and planned exercises are not independently delta-synced — "
                    + "whenever a session appears here, replace all of its local children. "
                    + "Response is a standard Spring Data page.")
    @GetMapping(params = "updatedSince")
    public Page<WorkoutSessionResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return workoutSessionService.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Log a workout session")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public WorkoutSessionResponse create(@Valid @RequestBody WorkoutSessionRequest request) {
        return workoutSessionService.create(request);
    }

    @Operation(summary = "Update a workout session (e.g. finish an in-progress one)")
    @PutMapping("/{id}")
    public WorkoutSessionResponse update(@PathVariable Long id,
                                         @Valid @RequestBody WorkoutSessionRequest request) {
        return workoutSessionService.update(id, request);
    }

    @Operation(summary = "Delete a workout session")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        workoutSessionService.delete(id);
    }
}
