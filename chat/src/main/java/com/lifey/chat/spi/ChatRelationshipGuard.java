package com.lifey.chat.spi;

import java.util.Optional;

/**
 * Answers the one question the chat asks of the trainer module: may these two
 * people talk to each other right now?
 */
public interface ChatRelationshipGuard {

    /** @return the link if it exists <em>and</em> is active, empty otherwise */
    Optional<ChatRelationship> findActive(Long trainerClientId);

    /**
     * Role-agnostic lookup: the caller may be the peer's trainer or their
     * client, and the chat does not care which — both directions are the same
     * 1:1 thread.
     */
    Optional<ChatRelationship> findActiveBetween(Long userId, Long peerUserId);
}
