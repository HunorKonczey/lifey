package com.lifey.trainer.controller;

import com.lifey.trainer.dto.ProgramAssignmentRequest;
import com.lifey.trainer.dto.ProgramAssignmentResponse;
import com.lifey.trainer.dto.ProgramAssignmentSummaryResponse;
import com.lifey.trainer.service.ProgramAssignmentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Trainer Program Assignments", description = "Starting a client on a multi-week program (docs/34-multi-week-program-plan.md)")
@RestController
@RequiredArgsConstructor
public class ProgramAssignmentController {

    private final ProgramAssignmentService programAssignmentService;

    @Operation(summary = "Start a client on a program",
            description = "Materializes every slot in the program's grid as an upcoming workout_sessions "
                    + "occurrence, starting from the given Monday.")
    @PostMapping("/api/v1/trainer/programs/{programId}/assignments")
    @ResponseStatus(HttpStatus.CREATED)
    public ProgramAssignmentResponse assign(@PathVariable Long programId, @Valid @RequestBody ProgramAssignmentRequest request) {
        return programAssignmentService.assign(programId, request);
    }

    @Operation(summary = "List a client's program assignments, with done/missed/remaining occurrence counts")
    @GetMapping("/api/v1/trainer/clients/{clientId}/program-assignments")
    public List<ProgramAssignmentSummaryResponse> findForClient(@PathVariable Long clientId) {
        return programAssignmentService.findForClient(clientId);
    }

    @Operation(summary = "Cancel a program assignment",
            description = "Soft-deletes its future, not-yet-started occurrences; past occurrences are untouched.")
    @DeleteMapping("/api/v1/trainer/program-assignments/{assignmentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@PathVariable Long assignmentId) {
        programAssignmentService.cancel(assignmentId);
    }
}
