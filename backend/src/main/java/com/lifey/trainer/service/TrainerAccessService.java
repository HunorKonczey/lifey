package com.lifey.trainer.service;

import com.lifey.trainer.dto.MyTrainerResponse;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.dto.TrainerClientResponse;

import java.util.List;

public interface TrainerAccessService {

    /**
     * Guards every trainer endpoint that reads a specific client's data:
     * throws {@link com.lifey.trainer.exception.NotYourClientException} (403)
     * unless {@code trainerId} has an ACTIVE relationship with {@code clientId}.
     */
    TrainerClient requireActiveClient(Long trainerId, Long clientId);

    List<TrainerClientResponse> findActiveClientsForTrainer();

    void revokeClient(Long clientId);

    List<MyTrainerResponse> findActiveTrainersForClient();

    void leaveTrainer(Long trainerId);
}
