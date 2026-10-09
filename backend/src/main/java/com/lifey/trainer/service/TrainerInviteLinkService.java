package com.lifey.trainer.service;

import com.lifey.trainer.dto.CreatedTrainerInviteLinkResponse;
import com.lifey.trainer.dto.InviteLinkPreviewResponse;
import com.lifey.trainer.dto.TrainerInviteLinkResponse;

import java.util.List;

public interface TrainerInviteLinkService {

    /** Makes a single-use join link for the current trainer (LIF-103); the token is in the answer, once. */
    CreatedTrainerInviteLinkResponse create();

    /** The current trainer's links that can still be used, newest first. */
    List<TrainerInviteLinkResponse> findActiveForTrainer();

    /** Takes a link back. A link that is already used, expired or revoked is "not found". */
    void revoke(Long linkId);

    /** Who is inviting, for the public landing page. Not found for any link that can no longer be used. */
    InviteLinkPreviewResponse preview(String token);

    /**
     * The signed-in user takes the link: they become the trainer's client, as if they had accepted an email invite,
     * and the link is spent.
     */
    void redeem(String token);
}
