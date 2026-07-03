package com.lifey.trainer;

import com.lifey.trainer.dto.TrainerClientResponse;
import com.lifey.trainer.service.TrainerAccessService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Trainer Clients", description = "Trainer-side view of active clients (web admin)")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer/clients")
public class TrainerClientController {

    private final TrainerAccessService trainerAccessService;

    @Operation(summary = "List this trainer's active clients")
    @GetMapping
    public List<TrainerClientResponse> findActiveClients() {
        return trainerAccessService.findActiveClientsForTrainer();
    }

    @Operation(summary = "End the relationship with a client")
    @DeleteMapping("/{clientId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revoke(@PathVariable Long clientId) {
        trainerAccessService.revokeClient(clientId);
    }
}
