package com.lifey.trainer.dto;

/** What a visitor sees before signing in: who is inviting them. Only for a link that can still be used. */
public record InviteLinkPreviewResponse(
        String trainerName
) {
}
