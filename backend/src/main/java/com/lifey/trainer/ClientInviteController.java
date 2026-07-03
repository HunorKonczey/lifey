package com.lifey.trainer;

import com.lifey.trainer.dto.PendingInviteResponse;
import com.lifey.trainer.dto.RespondToInviteRequest;
import com.lifey.trainer.service.TrainerInviteService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Client Invites", description = "Client-side (mobile) view of trainer invites")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer-invites")
public class ClientInviteController {

    private final TrainerInviteService trainerInviteService;

    @Operation(summary = "List this user's pending (non-expired) trainer invites",
            description = "Polled on app start/foreground — see docs/personal_trainer/05-mobil-terv.md.")
    @GetMapping("/pending")
    public List<PendingInviteResponse> findPending() {
        return trainerInviteService.findPendingForClient();
    }

    @Operation(summary = "Accept or decline a pending invite")
    @PostMapping("/{id}/respond")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void respond(@PathVariable Long id, @Valid @RequestBody RespondToInviteRequest request) {
        trainerInviteService.respond(id, request);
    }
}
