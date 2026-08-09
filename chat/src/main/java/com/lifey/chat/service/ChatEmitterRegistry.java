package com.lifey.chat.service;

import com.lifey.chat.dto.ChatEvent;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * The live SSE connections of this instance, keyed by user (a user can be on
 * their phone and a browser tab at once, hence a set).
 *
 * <p><b>This class stays local even when the fan-out stops being local.</b>
 * A socket cannot be shared between JVMs, so a future
 * {@code PostgresChatEventBus} (LISTEN/NOTIFY, §2 "skálázási seam") would still
 * end up calling {@link #send} on whichever instance holds the connection. That
 * is why the registry and the {@link ChatEventBus} are two classes: the bus is
 * the replaceable transport, the registry is not.
 *
 * <p><b>Leak protection is threefold</b> (§9): all three emitter callbacks
 * unregister, a failed write unregisters immediately, and every connection has
 * a bounded lifetime from {@code lifey.chat.stream-timeout} — so even a
 * connection nobody notices dying is gone within that window.
 */
@Slf4j
@Component
public class ChatEmitterRegistry {

    private final Map<Long, Set<SseEmitter>> emittersByUser = new ConcurrentHashMap<>();

    /**
     * @param onDisconnect run after the emitter has been dropped from the map.
     *                     Spring's {@code onCompletion} keeps a single delegate,
     *                     so callers must hand their cleanup in here rather than
     *                     registering a second callback that would silently
     *                     replace this one.
     */
    public void register(Long userId, SseEmitter emitter, Runnable onDisconnect) {
        emittersByUser.computeIfAbsent(userId, id -> ConcurrentHashMap.newKeySet()).add(emitter);
        emitter.onCompletion(() -> {
            remove(userId, emitter);
            onDisconnect.run();
        });
        emitter.onTimeout(() -> {
            // Completing here rather than leaving it to the container is what
            // makes onCompletion fire, which is what actually frees the entry.
            emitter.complete();
            remove(userId, emitter);
        });
        emitter.onError(error -> {
            remove(userId, emitter);
            onDisconnect.run();
        });
    }

    /** Write to one specific connection — the {@code Last-Event-ID} replay path. */
    public boolean sendTo(Long userId, SseEmitter emitter, ChatEvent event) {
        return write(userId, emitter, event);
    }

    /**
     * Padding written ahead of the first real frame, sized to push any
     * intermediary's write buffer past its threshold immediately.
     *
     * <p>A proxy that holds a response until it has N bytes turns "connected"
     * into "connected in a few minutes" on a stream whose frames are a few
     * hundred bytes each. 2 KB of comment is nothing to send once per
     * connection and is the conventional size for this.
     */
    private static final String BUFFER_PRIMER = " ".repeat(2048);

    /**
     * A comment frame written the moment a stream opens.
     *
     * <p>Not cosmetic: until something is written, the servlet container has
     * not committed the response, so the client's request does not resolve and
     * the stream looks dead. With nothing else to say on connect — a client
     * with no cursor gets no replay — the first byte would otherwise be the
     * next heartbeat, leaving every connect (and every reconnect) blind for up
     * to {@code lifey.chat.stream-heartbeat}. Measured at ~20s before this
     * existed; see the I4 load-sanity record in the plan.
     */
    public void sendOpeningComment(Long userId, SseEmitter emitter) {
        try {
            emitter.send(SseEmitter.event().comment(BUFFER_PRIMER).comment("connected"));
        } catch (IOException | IllegalStateException ex) {
            log.debug("Chat stream for user {} closed before it opened: {}", userId, ex.getMessage());
            remove(userId, emitter);
        }
    }

    /** True when at least one of this user's clients is holding a stream open. */
    public boolean isConnected(Long userId) {
        Set<SseEmitter> emitters = emittersByUser.get(userId);
        return emitters != null && !emitters.isEmpty();
    }

    /**
     * Fan out to every connection this user has here.
     *
     * @return true if the event reached at least one connection — the caller
     * uses this to decide whether the message counts as delivered
     */
    public boolean send(Long userId, ChatEvent event) {
        Set<SseEmitter> emitters = emittersByUser.get(userId);
        if (emitters == null || emitters.isEmpty()) {
            return false;
        }
        boolean delivered = false;
        for (SseEmitter emitter : emitters) {
            delivered |= write(userId, emitter, event);
        }
        return delivered;
    }

    /**
     * Comment frames on a schedule. Two jobs: proxies that close idle
     * connections see traffic, and a connection the peer dropped without a FIN
     * fails on write here instead of lingering until its timeout.
     *
     * <p>Runs on the shared single-threaded scheduler, alongside the cron jobs.
     * That is fine at the scale this is built for (§9's sanity bar is 200
     * concurrent emitters), but it is the first thing to move to its own pool
     * if the connection count grows — a write blocking on a full socket buffer
     * would hold up every other scheduled job behind it.
     */
    @Scheduled(fixedDelayString = "${lifey.chat.stream-heartbeat:20s}")
    public void heartbeat() {
        emittersByUser.forEach((userId, emitters) -> {
            for (SseEmitter emitter : emitters) {
                try {
                    emitter.send(SseEmitter.event().comment("ping"));
                } catch (IOException | IllegalStateException ex) {
                    remove(userId, emitter);
                }
            }
        });
    }

    /** Gauge for the leak alarm from §9 / I7. */
    public int connectionCount() {
        return emittersByUser.values().stream().mapToInt(Set::size).sum();
    }

    private boolean write(Long userId, SseEmitter emitter, ChatEvent event) {
        try {
            SseEmitter.SseEventBuilder frame = SseEmitter.event()
                    .name(event.name())
                    .data(event.data(), MediaType.APPLICATION_JSON);
            if (event.id() != null) {
                frame.id(String.valueOf(event.id()));
            }
            emitter.send(frame);
            return true;
        } catch (IOException | IllegalStateException ex) {
            // A closed tab or a dead socket, not an error worth a stack trace:
            // the client will reconnect and catch up from Last-Event-ID.
            log.debug("Dropping chat stream for user {}: {}", userId, ex.getMessage());
            remove(userId, emitter);
            return false;
        }
    }

    private void remove(Long userId, SseEmitter emitter) {
        emittersByUser.computeIfPresent(userId, (id, emitters) -> {
            emitters.remove(emitter);
            // Returning null drops the key, so an idle user leaves nothing behind.
            return emitters.isEmpty() ? null : emitters;
        });
    }
}
