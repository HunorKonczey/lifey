package com.lifey.chat.service;

import com.lifey.chat.dto.ChatEvent;
import com.lifey.chat.dto.ResyncEventPayload;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.function.Consumer;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

/**
 * The registry's whole job is to not leak connections (§9), so that is what
 * these check: every way a connection can end frees its entry, and a user with
 * no connections leaves no key behind.
 *
 * <p>The emitters are mocks because {@code SseEmitter.complete()} only notifies
 * the MVC handler that owns the async request — outside a servlet container it
 * does nothing at all, and the lifecycle callbacks would never fire. Capturing
 * the callbacks and running them is the same thing the container does.
 */
class ChatEmitterRegistryTest {

    private static final Long USER_ID = 7L;

    private final ChatEmitterRegistry registry = new ChatEmitterRegistry();

    @Test
    void registeringMakesTheUserConnected() {
        registry.register(USER_ID, mock(SseEmitter.class), noCleanup());

        assertThat(registry.isConnected(USER_ID)).isTrue();
        assertThat(registry.connectionCount()).isEqualTo(1);
    }

    @Test
    void completingAConnectionUnregistersItAndRunsTheCleanup() {
        SseEmitter emitter = mock(SseEmitter.class);
        boolean[] cleanedUp = {false};
        registry.register(USER_ID, emitter, () -> cleanedUp[0] = true);

        completionCallbackOf(emitter).run();

        assertThat(registry.isConnected(USER_ID)).isFalse();
        assertThat(registry.connectionCount()).isZero();
        assertThat(cleanedUp[0]).isTrue();
    }

    @Test
    void aTimedOutConnectionUnregisters() {
        SseEmitter emitter = mock(SseEmitter.class);
        registry.register(USER_ID, emitter, noCleanup());

        ArgumentCaptor<Runnable> timeout = ArgumentCaptor.captor();
        verify(emitter).onTimeout(timeout.capture());
        timeout.getValue().run();

        // Completing explicitly is what makes the container fire onCompletion —
        // without it a timed-out emitter would linger until the request ended.
        verify(emitter).complete();
        assertThat(registry.connectionCount()).isZero();
    }

    @Test
    void anErroredConnectionUnregistersToo() {
        SseEmitter emitter = mock(SseEmitter.class);
        boolean[] cleanedUp = {false};
        registry.register(USER_ID, emitter, () -> cleanedUp[0] = true);

        ArgumentCaptor<Consumer<Throwable>> error = ArgumentCaptor.captor();
        verify(emitter).onError(error.capture());
        error.getValue().accept(new IllegalStateException("client vanished"));

        assertThat(registry.connectionCount()).isZero();
        assertThat(cleanedUp[0]).isTrue();
    }

    @Test
    void oneUserCanHoldSeveralConnections() {
        SseEmitter phone = mock(SseEmitter.class);
        SseEmitter browser = mock(SseEmitter.class);
        registry.register(USER_ID, phone, noCleanup());
        registry.register(USER_ID, browser, noCleanup());

        completionCallbackOf(phone).run();

        // Closing the phone must not take the browser tab's stream with it.
        assertThat(registry.isConnected(USER_ID)).isTrue();
        assertThat(registry.connectionCount()).isEqualTo(1);
    }

    @Test
    void sendingToAUserWithoutConnections_reportsNotDelivered() {
        assertThat(registry.send(USER_ID, resync())).isFalse();
    }

    @Test
    void sendingToAConnectedUser_reportsDelivered() {
        registry.register(USER_ID, mock(SseEmitter.class), noCleanup());

        assertThat(registry.send(USER_ID, resync())).isTrue();
    }

    @Test
    void aFailedWriteDropsTheConnectionInsteadOfKeepingADeadOne() throws IOException {
        SseEmitter dead = mock(SseEmitter.class);
        doThrow(new IOException("broken pipe")).when(dead).send(any(SseEmitter.SseEventBuilder.class));
        registry.register(USER_ID, dead, noCleanup());

        assertThat(registry.send(USER_ID, resync())).isFalse();
        assertThat(registry.connectionCount()).isZero();
    }

    @Test
    void heartbeatDropsConnectionsThatCanNoLongerBeWrittenTo() throws IOException {
        SseEmitter dead = mock(SseEmitter.class);
        doThrow(new IOException("broken pipe")).when(dead).send(any(SseEmitter.SseEventBuilder.class));
        registry.register(USER_ID, dead, noCleanup());

        registry.heartbeat();

        verify(dead).send(any(SseEmitter.SseEventBuilder.class));
        assertThat(registry.connectionCount()).isZero();
    }

    private static Runnable completionCallbackOf(SseEmitter emitter) {
        ArgumentCaptor<Runnable> completion = ArgumentCaptor.captor();
        verify(emitter).onCompletion(completion.capture());
        return completion.getValue();
    }

    private static Runnable noCleanup() {
        return () -> {
        };
    }

    private static ChatEvent resync() {
        return new ChatEvent(ChatEvent.RESYNC, null, new ResyncEventPayload("test"));
    }
}
