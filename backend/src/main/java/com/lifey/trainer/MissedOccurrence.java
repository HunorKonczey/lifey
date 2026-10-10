package com.lifey.trainer;

import java.time.LocalDate;

/**
 * A trainer-scheduled occurrence that may need announcing as missed (docs/85-trainer-push-plan.md): which session, whose
 * schedule (the trainer is who gets told), which client, and the trainer's offset for "08:00 their local time".
 */
public record MissedOccurrence(
        Long sessionId,
        LocalDate scheduledFor,
        String workoutName,
        Long trainerId,
        int trainerUtcOffsetMinutes,
        Long clientId,
        String clientEmail,
        String clientFirstName,
        String clientLastName
) {

    /** What the trainer calls the client: the full name, the e-mail when there is none. */
    public String clientDisplayName() {
        String first = clientFirstName == null ? "" : clientFirstName.trim();
        String last = clientLastName == null ? "" : clientLastName.trim();
        String full = (first + " " + last).trim();
        return full.isEmpty() ? clientEmail : full;
    }
}
