package com.lifey.workout.template;

import com.lifey.workout.template.dto.WorkoutTemplateRequest;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

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
    @GetMapping
    public List<WorkoutTemplateResponse> findAll() {
        return workoutTemplateService.findAll();
    }

    @Operation(summary = "Create a workout template")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public WorkoutTemplateResponse create(@Valid @RequestBody WorkoutTemplateRequest request) {
        return workoutTemplateService.create(request);
    }
}
