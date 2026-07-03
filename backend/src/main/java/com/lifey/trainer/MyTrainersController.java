package com.lifey.trainer;

import com.lifey.trainer.dto.MyTrainerResponse;
import com.lifey.trainer.service.TrainerAccessService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "My Trainers", description = "Client-side (mobile Settings) view of active trainers")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/my-trainers")
public class MyTrainersController {

    private final TrainerAccessService trainerAccessService;

    @Operation(summary = "List this user's active trainers")
    @GetMapping
    public List<MyTrainerResponse> findActiveTrainers() {
        return trainerAccessService.findActiveTrainersForClient();
    }

    @Operation(summary = "Leave a trainer relationship")
    @DeleteMapping("/{trainerId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@PathVariable Long trainerId) {
        trainerAccessService.leaveTrainer(trainerId);
    }
}
