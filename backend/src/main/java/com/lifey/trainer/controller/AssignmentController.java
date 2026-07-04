package com.lifey.trainer.controller;

import com.lifey.trainer.dto.AssignmentListItemResponse;
import com.lifey.trainer.dto.AssignmentRequest;
import com.lifey.trainer.dto.AssignmentResponse;
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
@RequiredArgsConstructor
public class AssignmentController {

    private final ContentAssignmentService contentAssignmentService;

    @Operation(summary = "Assign a workout template or recipe to a client",
            description = "Deep-copies the trainer's own template/recipe (and everything it "
                    + "references) into the client's account. Re-assigning the same source "
                    + "always creates a fresh copy rather than versioning the previous one — "
                    + "`previouslyAssigned` in the response tells the UI to warn about that.")
    @PostMapping("/api/v1/trainer/assignments")
    @ResponseStatus(HttpStatus.CREATED)
    public AssignmentResponse assign(@Valid @RequestBody AssignmentRequest request) {
        return contentAssignmentService.assign(request);
    }

    @Operation(summary = "List everything this trainer has assigned to a given client")
    @GetMapping("/api/v1/trainer/clients/{clientId}/assignments")
    public List<AssignmentListItemResponse> findForClient(@PathVariable Long clientId) {
        return contentAssignmentService.findForClient(clientId);
    }
}
