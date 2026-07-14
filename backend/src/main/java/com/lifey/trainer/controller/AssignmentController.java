package com.lifey.trainer.controller;

import com.lifey.trainer.ContentType;
import com.lifey.trainer.dto.AssignmentListItemResponse;
import com.lifey.trainer.dto.AssignmentRequest;
import com.lifey.trainer.dto.BulkAssignmentResponse;
import com.lifey.trainer.service.ContentAssignmentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Trainer Assignments", description = "Deep-copy a trainer's own template/recipe into a client's account")
@RestController
@RequestMapping("/api/v1/trainer")
@RequiredArgsConstructor
public class AssignmentController {

    private final ContentAssignmentService contentAssignmentService;

    @Operation(summary = "Assign a workout template or recipe to one or more clients",
            description = "Deep-copies the trainer's own template/recipe (and everything it "
                    + "references) into each client's account, atomically for the whole batch. "
                    + "Clients who already have this content are skipped and reported in "
                    + "`skippedClientIds` (retries are idempotent); a revoked client or a "
                    + "missing source fails the entire request with zero writes.")
    @PostMapping("/assignments")
    @ResponseStatus(HttpStatus.CREATED)
    public BulkAssignmentResponse assign(@Valid @RequestBody AssignmentRequest request) {
        return contentAssignmentService.assign(request);
    }

    @Operation(summary = "List everything this trainer has assigned to a given client")
    @GetMapping("/clients/{clientId}/assignments")
    public List<AssignmentListItemResponse> findForClient(@PathVariable Long clientId) {
        return contentAssignmentService.findForClient(clientId);
    }

    @Operation(summary = "List the client ids this trainer has already assigned this content to",
            description = "Used by the assign dialog to pre-check clients that already have this template/recipe.")
    @GetMapping("/assignments/clients")
    public List<Long> findAssignedClientIds(@RequestParam ContentType contentType, @RequestParam Long sourceId) {
        return contentAssignmentService.findAssignedClientIds(contentType, sourceId);
    }

    @Operation(summary = "Remove an assignment",
            description = "Also soft-deletes the client's copy the assignment created.")
    @DeleteMapping("/assignments/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unassign(@PathVariable Long id) {
        contentAssignmentService.unassign(id);
    }
}
