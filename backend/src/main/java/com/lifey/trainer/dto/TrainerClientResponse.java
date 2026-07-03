package com.lifey.trainer.dto;

import java.time.Instant;

/** An active client as seen by the trainer. */
public record TrainerClientResponse(
        Long clientId,
        String clientEmail,
        Instant activeSince
) {
}
