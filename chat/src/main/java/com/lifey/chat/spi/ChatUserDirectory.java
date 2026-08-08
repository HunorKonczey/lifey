package com.lifey.chat.spi;

import java.util.Collection;
import java.util.Map;
import java.util.Optional;

/**
 * Resolves the handful of user fields a thread renders (see {@link ChatUser}).
 */
public interface ChatUserDirectory {

    Optional<ChatUser> find(Long userId);

    /**
     * Batch variant for the conversation list, which renders one peer per row —
     * resolving them one at a time would be an N+1.
     *
     * @return only the ids that exist; a caller asking about a deleted user gets
     *         a map without that key rather than a null value
     */
    Map<Long, ChatUser> findAll(Collection<Long> userIds);
}
