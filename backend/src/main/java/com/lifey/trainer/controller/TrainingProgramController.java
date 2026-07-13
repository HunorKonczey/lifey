package com.lifey.trainer.controller;

import com.lifey.trainer.dto.ProgramRequest;
import com.lifey.trainer.dto.ProgramResponse;
import com.lifey.trainer.dto.ProgramSummaryResponse;
import com.lifey.trainer.service.TrainingProgramService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Trainer Programs", description = "Multi-week program blueprints (docs/34-multi-week-program-plan.md)")
@RestController
@RequestMapping("/api/v1/trainer/programs")
@RequiredArgsConstructor
public class TrainingProgramController {

    private final TrainingProgramService trainingProgramService;

    @Operation(summary = "Create a multi-week program",
            description = "A week x day grid of workout template slots (at most one per week/day cell).")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProgramResponse create(@Valid @RequestBody ProgramRequest request) {
        return trainingProgramService.create(request);
    }

    @Operation(summary = "List this trainer's programs",
            description = "Summaries only: weekly slot count and how many clients currently have this program active.")
    @GetMapping
    public List<ProgramSummaryResponse> findAll() {
        return trainingProgramService.findAll();
    }

    @Operation(summary = "Get a program's full grid")
    @GetMapping("/{programId}")
    public ProgramResponse findById(@PathVariable Long programId) {
        return trainingProgramService.findById(programId);
    }

    @Operation(summary = "Replace a program's name/weeks/slots",
            description = "Full overwrite. Does not affect clients already assigned this program.")
    @PutMapping("/{programId}")
    public ProgramResponse update(@PathVariable Long programId, @Valid @RequestBody ProgramRequest request) {
        return trainingProgramService.update(programId, request);
    }

    @Operation(summary = "Delete a program",
            description = "Soft delete. Existing client assignments are materialized snapshots and keep working.")
    @DeleteMapping("/{programId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long programId) {
        trainingProgramService.delete(programId);
    }
}
