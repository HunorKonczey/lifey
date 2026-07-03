package com.lifey.trainer;

import com.lifey.trainer.dto.TrainerInviteRequest;
import com.lifey.trainer.dto.TrainerInviteResponse;
import com.lifey.trainer.service.TrainerInviteService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Trainer Invites", description = "Trainer-side invite management (web admin)")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer/invites")
public class TrainerInviteController {

    private final TrainerInviteService trainerInviteService;

    @Operation(summary = "Invite a client by exact email")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TrainerInviteResponse invite(@Valid @RequestBody TrainerInviteRequest request) {
        return trainerInviteService.invite(request);
    }

    @Operation(summary = "List this trainer's pending (non-expired) invites")
    @GetMapping
    public List<TrainerInviteResponse> findPending() {
        return trainerInviteService.findPendingForTrainer();
    }

    @Operation(summary = "Cancel a pending invite")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@PathVariable Long id) {
        trainerInviteService.cancel(id);
    }
}
