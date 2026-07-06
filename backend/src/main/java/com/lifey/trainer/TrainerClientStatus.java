package com.lifey.trainer;

/**
 * Lifecycle of a trainer-client relationship — see
 * docs/personal_trainer/01-koncepcio-es-folyamatok.md "1. folyamat".
 */
public enum TrainerClientStatus {
    /** Sent, not yet answered, and not yet past its 24h {@code expiresAt}. */
    PENDING,
    ACTIVE,
    DECLINED,
    /** Torn down by either the trainer or the client after being ACTIVE. */
    REVOKED,
    /** A PENDING invite whose 24h window passed; set by {@link TrainerClientCleanupJob}. */
    EXPIRED
}
