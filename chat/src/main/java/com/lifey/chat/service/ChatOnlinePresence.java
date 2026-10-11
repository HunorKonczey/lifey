package com.lifey.chat.service;

import com.lifey.chat.dto.ChatEvent;
import com.lifey.chat.dto.OnlineEventPayload;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatParticipantRepository;
import com.lifey.chat.spi.ChatPresencePreferences;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
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
 * <p><b>The switch (LIF-153).</b> A user who turned "show when I am online" off is never announced, and - reciprocally - is
 * never told about anybody else either: you do not get to watch people while hiding yourself. Both directions are decided here
 * from {@link ChatPresencePreferences}, in one batch per decision. The setting lives in the monolith and changes while people
 * are connected, so {@link #reconcile()} re-reads it on a timer for everybody online and hides or shows them without waiting
 * for their next connect - which also means the settings save does not have to call this service, and works when the phone
 * saved it offline and it reached the server later.
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
    private final ChatPresencePreferences preferences;
    private final TaskScheduler scheduler;
    private final Duration grace;

    /** Users whose peers currently believe they are online. */
    private final Set<Long> announced = ConcurrentHashMap.newKeySet();
    private final Map<Long, ScheduledFuture<?>> pendingOffline = new ConcurrentHashMap<>();

    public ChatOnlinePresence(ChatParticipantRepository participantRepository,
                              ChatEmitterRegistry registry,
                              ChatEventBus eventBus,
                              ChatPresencePreferences preferences,
                              TaskScheduler scheduler,
                              @Value("${lifey.chat.online-grace:15s}") Duration grace) {
        this.participantRepository = participantRepository;
        this.registry = registry;
        this.eventBus = eventBus;
        this.preferences = preferences;
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
        Set<Long> hidden = preferences.hiddenAmong(withSelf(userId, peers));
        if (hidden.contains(userId)) {
            // Hiding yourself hides everybody else from you, too: nothing announced, no starting state.
            return;
        }
        List<Long> visiblePeers = peers.stream().filter(peer -> !hidden.contains(peer)).toList();
        if (announced.add(userId)) {
            tell(visiblePeers, userId, true);
        }
        // The starting state of the connecting client: who of its peers is here now.
        for (Long peer : visiblePeers) {
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
            List<Long> peers = openThreadPeers(userId);
            Set<Long> hidden = preferences.hiddenAmong(peers);
            tell(peers.stream().filter(peer -> !hidden.contains(peer)).toList(), userId, false);
        } catch (RuntimeException ex) {
            log.warn("Could not announce user {} going offline", userId, ex);
        }
    }

    /**
     * Applies a changed switch to everybody who is online (or believed to be): a user who just turned it off disappears from
     * their peers - and the peers from them - and one who turned it on appears. Runs often enough that a flipped switch feels
     * immediate, and does one settings query per tick whatever the number of connections.
     */
    @Scheduled(fixedDelayString = "${lifey.chat.online-reconcile:30s}")
    public void reconcile() {
        try {
            Set<Long> connected = registry.connectedUserIds();
            Set<Long> everybody = new HashSet<>(connected);
            everybody.addAll(announced);
            if (everybody.isEmpty()) {
                return;
            }
            Set<Long> hidden = preferences.hiddenAmong(everybody);
            for (Long userId : Set.copyOf(announced)) {
                if (hidden.contains(userId)) {
                    hide(userId);
                }
            }
            for (Long userId : connected) {
                if (!hidden.contains(userId) && !announced.contains(userId)) {
                    show(userId);
                }
            }
        } catch (RuntimeException ex) {
            log.warn("Online presence reconcile failed", ex);
        }
    }

    /** The user turned the switch off while online: peers lose them, and they lose the peers. */
    private void hide(Long userId) {
        announced.remove(userId);
        List<Long> peers = openThreadPeers(userId);
        Set<Long> hidden = preferences.hiddenAmong(peers);
        List<Long> visiblePeers = peers.stream().filter(peer -> !hidden.contains(peer)).toList();
        tell(visiblePeers, userId, false);
        for (Long peer : visiblePeers) {
            if (eventBus.isConnected(peer)) {
                eventBus.publish(userId, ChatEvent.ofOnline(new OnlineEventPayload(peer, false)));
            }
        }
    }

    /** The user turned the switch on while connected: they appear to their peers, and see who is here. */
    private void show(Long userId) {
        announced.add(userId);
        List<Long> peers = openThreadPeers(userId);
        Set<Long> hidden = preferences.hiddenAmong(peers);
        List<Long> visiblePeers = peers.stream().filter(peer -> !hidden.contains(peer)).toList();
        tell(visiblePeers, userId, true);
        for (Long peer : visiblePeers) {
            if (eventBus.isConnected(peer)) {
                eventBus.publish(userId, ChatEvent.ofOnline(new OnlineEventPayload(peer, true)));
            }
        }
    }

    private void tell(List<Long> peers, Long about, boolean online) {
        for (Long peer : peers) {
            eventBus.publish(peer, ChatEvent.ofOnline(new OnlineEventPayload(about, online)));
        }
    }

    private static Set<Long> withSelf(Long userId, List<Long> peers) {
        Set<Long> all = new HashSet<>(peers);
        all.add(userId);
        return all;
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
