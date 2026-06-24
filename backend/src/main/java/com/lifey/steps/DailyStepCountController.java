package com.lifey.steps;

import com.lifey.steps.dto.DailyStepCountRequest;
import com.lifey.steps.dto.DailyStepCountResponse;
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

@Tag(name = "Step Tracking", description = "Persisted daily step counts")
@RestController
@RequestMapping("/api/v1/steps")
public class DailyStepCountController {

    private final DailyStepCountService stepCountService;

    public DailyStepCountController(DailyStepCountService stepCountService) {
        this.stepCountService = stepCountService;
    }

    @Operation(summary = "List all daily step counts (newest first)")
    @GetMapping
    public List<DailyStepCountResponse> findAll() {
        return stepCountService.findAll();
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
