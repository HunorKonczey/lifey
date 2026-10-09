package com.lifey.trainer.service;

import com.lifey.trainer.dto.PendingInviteResponse;
import com.lifey.trainer.dto.RespondToInviteRequest;
import com.lifey.trainer.dto.TrainerInviteRequest;
import com.lifey.trainer.dto.TrainerInviteHistoryResponse;
import com.lifey.trainer.dto.TrainerInviteResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;

public interface TrainerInviteService {

    TrainerInviteResponse invite(TrainerInviteRequest request);

    List<TrainerInviteResponse> findPendingForTrainer();

    /** Every invite this trainer sent, newest first, each with its outcome (docs/redesign-web/82 section 2.2). */
    Page<TrainerInviteHistoryResponse> findHistoryForTrainer(Pageable pageable);

    void cancel(Long inviteId);

    /**
     * Reminds the client of a pending invite (LIF-103): a push, and the invite email again when that channel is on —
     * with fresh accept / decline links, since the earlier ones cannot be recovered from their stored hash. At most one
     * reminder per cooldown, counted from the invite or from the last reminder; the invite's own expiry is unchanged.
     */
    TrainerInviteResponse remind(Long inviteId);

    List<PendingInviteResponse> findPendingForClient();

    void respond(Long inviteId, RespondToInviteRequest request);

    /**
     * Accepts or declines a PENDING invite by its emailed accept/decline token,
     * rather than by id + authenticated client (see {@link #respond}). Used by
     * the public, unauthenticated email links.
     */
    void respondViaEmailToken(String token, boolean accept);
}
