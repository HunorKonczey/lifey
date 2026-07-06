package com.lifey.trainer.dto;

import java.time.Instant;

/** An active trainer as seen by the client, for the mobile Settings screen. */
public record MyTrainerResponse(
        Long trainerId,
        String trainerEmail,
        String trainerFirstName,
        String trainerLastName,
        Instant activeSince
) {
}
