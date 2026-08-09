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

    /**
     * Whether these two users are linked right now, in either direction. The
     * one relationship question that is not asked from a trainer's point of
     * view: the chat — and the profile pictures it renders — is the same
     * feature for both sides of the pair.
     */
    boolean isActivelyLinked(Long userId, Long otherUserId);

    List<TrainerClientResponse> findActiveClientsForTrainer();

    void revokeClient(Long clientId);

    List<MyTrainerResponse> findActiveTrainersForClient();

    void leaveTrainer(Long trainerId);
}
