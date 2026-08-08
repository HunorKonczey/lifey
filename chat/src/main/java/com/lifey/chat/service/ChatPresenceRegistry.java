package com.lifey.chat.service;

import com.lifey.chat.ChatProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Which thread each user currently has open (§4.3). Deliberately in memory and
 * deliberately expiring: this is losable state, and the failure it causes is
 * the harmless direction — we send a push the recipient did not strictly need.
 * Persisting it would buy nothing and cost a write on every screen change.
 *
 * <p>The TTL matters because clients do not always get to say goodbye: a killed
 * app never sends {@code presence(null)}, and without an expiry that user would
 * look forever "in the thread" and never be pushed again.
 */
@Component
@RequiredArgsConstructor
public class ChatPresenceRegistry {

    /** Above this many tracked users, drop the expired ones before adding more. */
    private static final int PRUNE_THRESHOLD = 10_000;

    private final ChatProperties properties;
    private final Map<Long, Presence> presenceByUser = new ConcurrentHashMap<>();

    /** @param conversationId the thread being viewed, or null for "none" */
    public void set(Long userId, Long conversationId) {
        if (conversationId == null) {
            presenceByUser.remove(userId);
            return;
        }
        pruneIfLarge();
        presenceByUser.put(userId, new Presence(conversationId, Instant.now()));
    }

    /** The §5.1 question: is this user looking at this exact thread right now? */
    public boolean isViewing(Long userId, Long conversationId) {
        Presence presence = presenceByUser.get(userId);
        if (presence == null || !presence.conversationId().equals(conversationId)) {
            return false;
        }
        if (isExpired(presence)) {
            presenceByUser.remove(userId, presence);
            return false;
        }
        return true;
    }

    /** Called when a stream closes: a disconnected client is not viewing anything. */
    public void clear(Long userId) {
        presenceByUser.remove(userId);
    }

    private void pruneIfLarge() {
        if (presenceByUser.size() < PRUNE_THRESHOLD) {
            return;
        }
        presenceByUser.values().removeIf(this::isExpired);
    }

    private boolean isExpired(Presence presence) {
        Duration ttl = properties.presenceTtl();
        return ttl != null && Duration.between(presence.reportedAt(), Instant.now()).compareTo(ttl) > 0;
    }

    private record Presence(Long conversationId, Instant reportedAt) {
    }
}
