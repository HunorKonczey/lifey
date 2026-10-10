package com.lifey.chat.service;

import com.lifey.chat.dto.ChatEvent;
import com.lifey.chat.dto.OnlineEventPayload;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatParticipantRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ScheduledFuture;

/**
 * "Online" for the other side of a thread (LIF-122): the person has the app open, which is exactly when a chat stream is
 * connected here - the phone closes it in the background, the web keeps it for as long as the tab is open.
 *
 * <p>Peers are told with an {@code online} frame when someone's first connection opens and when their last one has been gone
 * for {@code lifey.chat.online-grace}. The grace is the point of the second half: a stream is recycled every few minutes and a
 * phone drops it on every app switch, and a dot that flickers off and on for each of those would be worse than none. A
 * connect inside the grace cancels the pending "offline" and tells nobody anything, because as far as the peers know the
 * person never left. A connecting client is also sent the peers that are online right now - that is how a client that was
 * offline itself, or is new, gets its starting state.
 *
 * <p>Only peers of open (non-archived) threads are ever told, and only about being connected - see {@link OnlineEventPayload}.
 * State is in memory like {@link ChatPresenceRegistry}: losing it on a restart only means the dot is missing until the next
 * connect.
 */
@Slf4j
@Component
public class ChatOnlinePresence {

    private final ChatParticipantRepository participantRepository;
    private final ChatEmitterRegistry registry;
    private final ChatEventBus eventBus;
    private final TaskScheduler scheduler;
    private final Duration grace;

    /** Users whose peers currently believe they are online. */
    private final Set<Long> announced = ConcurrentHashMap.newKeySet();
    private final Map<Long, ScheduledFuture<?>> pendingOffline = new ConcurrentHashMap<>();

    public ChatOnlinePresence(ChatParticipantRepository participantRepository,
                              ChatEmitterRegistry registry,
                              ChatEventBus eventBus,
                              TaskScheduler scheduler,
                              @Value("${lifey.chat.online-grace:15s}") Duration grace) {
        this.participantRepository = participantRepository;
        this.registry = registry;
        this.eventBus = eventBus;
        this.scheduler = scheduler;
        this.grace = grace;
    }

    /** A stream of {@code userId} was opened (it is already registered). */
    public void connected(Long userId, SseEmitter emitter) {
        ScheduledFuture<?> pending = pendingOffline.remove(userId);
        if (pending != null) {
            pending.cancel(false);
        }
        List<Long> peers = openThreadPeers(userId);
        if (announced.add(userId)) {
            for (Long peer : peers) {
                eventBus.publish(peer, ChatEvent.ofOnline(new OnlineEventPayload(userId, true)));
            }
        }
        // The starting state of the connecting client: who of its peers is here now.
        for (Long peer : peers) {
            if (eventBus.isConnected(peer)) {
                registry.sendTo(userId, emitter, ChatEvent.ofOnline(new OnlineEventPayload(peer, true)));
            }
        }
    }

    /** The last stream of {@code userId} is gone; their peers hear about it after the grace, unless they come back. */
    public void disconnected(Long userId) {
        ScheduledFuture<?> previous = pendingOffline.put(userId,
                scheduler.schedule(() -> expire(userId), Instant.now().plus(grace)));
        if (previous != null) {
            previous.cancel(false);
        }
    }

    void expire(Long userId) {
        pendingOffline.remove(userId);
        if (eventBus.isConnected(userId) || !announced.remove(userId)) {
            return;
        }
        try {
            for (Long peer : openThreadPeers(userId)) {
                eventBus.publish(peer, ChatEvent.ofOnline(new OnlineEventPayload(userId, false)));
            }
        } catch (RuntimeException ex) {
            log.warn("Could not announce user {} going offline", userId, ex);
        }
    }

    private List<Long> openThreadPeers(Long userId) {
        return participantRepository.findAllForUser(userId).stream()
                .map(ChatParticipant::getConversation)
                .filter(conversation -> conversation.getArchivedAt() == null)
                .map(conversation -> conversation.peerOf(userId))
                .distinct()
                .toList();
    }
}
