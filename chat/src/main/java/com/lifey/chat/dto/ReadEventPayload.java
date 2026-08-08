package com.lifey.chat.dto;

/**
 * Body of an {@code event: read} frame: how far the *other* participant has got
 * in the thread. Both cursors travel together because the sender's tick marks
 * are one three-state ladder (sent → delivered → read), and splitting them into
 * two frame types would only make the client reassemble them.
 *
 * @param userId                    whose cursors these are — always the peer,
 *                                  since a client never needs its own echoed back
 * @param lastDeliveredMessageId    reached the peer's device (their stream was
 *                                  live), null if nothing has been delivered yet
 * @param lastReadMessageId         the peer actually opened the thread this far,
 *                                  null if they never have
 */
public record ReadEventPayload(
        Long conversationId,
        Long userId,
        Long lastDeliveredMessageId,
        Long lastReadMessageId
) {
}
