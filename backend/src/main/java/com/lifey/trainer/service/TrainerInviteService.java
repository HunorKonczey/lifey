package com.lifey.trainer.service;

import com.lifey.trainer.dto.PendingInviteResponse;
import com.lifey.trainer.dto.RespondToInviteRequest;
import com.lifey.trainer.dto.TrainerInviteRequest;
import com.lifey.trainer.dto.TrainerInviteResponse;

import java.util.List;

public interface TrainerInviteService {

    TrainerInviteResponse invite(TrainerInviteRequest request);

    List<TrainerInviteResponse> findPendingForTrainer();

    void cancel(Long inviteId);

    List<PendingInviteResponse> findPendingForClient();

    void respond(Long inviteId, RespondToInviteRequest request);

    /**
     * Accepts or declines a PENDING invite by its emailed accept/decline token,
     * rather than by id + authenticated client (see {@link #respond}). Used by
     * the public, unauthenticated email links.
     */
    void respondViaEmailToken(String token, boolean accept);
}
