package com.lifey.workout.session;

import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Workout Sessions", description = "Logged workouts with sets, reps and weight")
@RestController
@RequestMapping("/api/v1/workout-sessions")
public class WorkoutSessionController {

    private final WorkoutSessionService workoutSessionService;

    public WorkoutSessionController(WorkoutSessionService workoutSessionService) {
        this.workoutSessionService = workoutSessionService;
    }

    @Operation(summary = "List all workout sessions (newest first)")
    @GetMapping
    public List<WorkoutSessionResponse> findAll() {
        return workoutSessionService.findAll();
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
