package com.lifey.chat.spi;

/**
 * An <em>active</em> trainer-client link — the authorization basis for the whole
 * chat (docs/chat/40-trainer-chat-plan.md §1.3/1): a thread exists only for a
 * live relationship, and it is frozen when that relationship ends.
 *
 * <p>There is no status field on purpose. {@link ChatRelationshipGuard} only
 * ever returns active links, so a {@code ChatRelationship} in hand <em>is</em>
 * the permission; nothing downstream has to re-check a flag and get it wrong.
 *
 * @param id the {@code trainer_clients} row id, denormalized onto the
 *           conversation so re-inviting a client produces a new thread rather
 *           than reviving the old one
 */
public record ChatRelationship(Long id, Long trainerId, Long clientId) {

    public boolean involves(Long userId) {
        return trainerId.equals(userId) || clientId.equals(userId);
    }
}
