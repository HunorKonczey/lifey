package com.lifey.trainer.controller;

import com.lifey.trainer.dto.CreatedTrainerInviteLinkResponse;
import com.lifey.trainer.dto.TrainerInviteLinkResponse;
import com.lifey.trainer.service.TrainerInviteLinkService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Trainer invite links")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer/invite-links")
public class TrainerInviteLinkController {

    private final TrainerInviteLinkService service;

    @Operation(summary = "Make a single-use join link",
            description = "The token is in the answer once and never again - only its hash is stored. Valid for 7 days; "
                    + "at most 5 live links per trainer; a trainer at the seat limit cannot make one.")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CreatedTrainerInviteLinkResponse create() {
        return service.create();
    }

    @Operation(summary = "This trainer's join links that can still be used, newest first")
    @GetMapping
    public List<TrainerInviteLinkResponse> findActive() {
        return service.findActiveForTrainer();
    }

    @Operation(summary = "Take a join link back")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revoke(@PathVariable Long id) {
        service.revoke(id);
    }
}
