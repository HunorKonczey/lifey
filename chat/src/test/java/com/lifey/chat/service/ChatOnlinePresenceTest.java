package com.lifey.chat.service;

import com.lifey.chat.dto.ChatEvent;
import com.lifey.chat.dto.OnlineEventPayload;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatParticipantRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.ScheduledFuture;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Who is told when (LIF-122): a first connection announces "online" to the peers of open threads, the last one leaving
 * announces "offline" only after the grace and only if the person did not come back, and a connecting client is sent which of
 * its peers are here now.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ChatOnlinePresenceTest {

    private static final Long USER = 7L;
    private static final Long PEER = 8L;
    private static final Long OTHER_PEER = 9L;

    @Mock
    ChatParticipantRepository participantRepository;

    @Mock
    ChatEmitterRegistry registry;

    @Mock
    ChatEventBus eventBus;

    @Mock
    TaskScheduler scheduler;

    @Mock
    SseEmitter emitter;

    ChatOnlinePresence presence;

    @BeforeEach
    void setUp() {
        presence = new ChatOnlinePresence(participantRepository, registry, eventBus, scheduler, Duration.ofSeconds(15));
        when(participantRepository.findAllForUser(USER)).thenReturn(List.of(
                participantIn(conversation(1L, USER, PEER, null)),
                participantIn(conversation(2L, USER, OTHER_PEER, null)),
                // An archived thread: nobody is told anything through it.
                participantIn(conversation(3L, USER, 10L, Instant.now()))));
    }

    @Test
    void aFirstConnectionTellsThePeersOfOpenThreads_notOfArchivedOnes() {
        presence.connected(USER, emitter);

        ArgumentCaptor<ChatEvent> frame = ArgumentCaptor.captor();
        verify(eventBus).publish(eq(PEER), frame.capture());
        verify(eventBus).publish(eq(OTHER_PEER), any(ChatEvent.class));
        verify(eventBus, never()).publish(eq(10L), any(ChatEvent.class));
        assertThat(frame.getValue().name()).isEqualTo(ChatEvent.ONLINE);
        assertThat(frame.getValue().id()).isNull();
        assertThat(frame.getValue().data()).isEqualTo(new OnlineEventPayload(USER, true));
    }

    @Test
    void aSecondConnectionOfTheSamePersonAnnouncesNothingNew() {
        presence.connected(USER, emitter);
        presence.connected(USER, emitter);

        verify(eventBus, times(1)).publish(eq(PEER), any(ChatEvent.class));
    }

    @Test
    void aConnectingClientIsToldWhichOfItsPeersAreHereNow() {
        when(eventBus.isConnected(PEER)).thenReturn(true);
        when(eventBus.isConnected(OTHER_PEER)).thenReturn(false);

        presence.connected(USER, emitter);

        ArgumentCaptor<ChatEvent> frame = ArgumentCaptor.captor();
        verify(registry).sendTo(eq(USER), eq(emitter), frame.capture());
        assertThat(frame.getValue().data()).isEqualTo(new OnlineEventPayload(PEER, true));
    }

    @Test
    void goingOffline_isAnnouncedOnlyAfterTheGrace_andOnlyIfTheyDidNotComeBack() {
        presence.connected(USER, emitter);
        ArgumentCaptor<Runnable> expiry = scheduleOneExpiry();

        // Still within the grace: nothing has been said.
        verify(eventBus, never()).publish(eq(PEER), eq(ChatEvent.ofOnline(new OnlineEventPayload(USER, false))));

        when(eventBus.isConnected(USER)).thenReturn(false);
        expiry.getValue().run();

        ArgumentCaptor<ChatEvent> frames = ArgumentCaptor.captor();
        verify(eventBus, times(2)).publish(eq(PEER), frames.capture());
        assertThat(frames.getAllValues().get(1).data()).isEqualTo(new OnlineEventPayload(USER, false));
    }

    @Test
    void comingBackInsideTheGrace_cancelsTheOfflineAndSaysNothing() {
        presence.connected(USER, emitter);
        ScheduledFuture<?> pending = mock(ScheduledFuture.class);
        when(scheduler.schedule(any(Runnable.class), any(Instant.class))).thenAnswer(inv -> pending);
        presence.disconnected(USER);

        presence.connected(USER, emitter);

        verify(pending).cancel(false);
        // Only the very first announcement: the peers never knew the person left.
        verify(eventBus, times(1)).publish(eq(PEER), any(ChatEvent.class));
    }

    @Test
    void ifAnotherConnectionIsBackWhenTheGraceEnds_nobodyIsTold() {
        presence.connected(USER, emitter);
        ArgumentCaptor<Runnable> expiry = scheduleOneExpiry();

        when(eventBus.isConnected(USER)).thenReturn(true);
        expiry.getValue().run();

        verify(eventBus, times(1)).publish(eq(PEER), any(ChatEvent.class));
    }

    @Test
    void aPersonWhoNeverWasAnnounced_isNotAnnouncedOffline() {
        ArgumentCaptor<Runnable> expiry = scheduleOneExpiry();
        when(eventBus.isConnected(USER)).thenReturn(false);

        expiry.getValue().run();

        verify(eventBus, never()).publish(any(), any(ChatEvent.class));
    }

    private ArgumentCaptor<Runnable> scheduleOneExpiry() {
        ArgumentCaptor<Runnable> expiry = ArgumentCaptor.captor();
        ScheduledFuture<?> future = mock(ScheduledFuture.class);
        when(scheduler.schedule(expiry.capture(), any(Instant.class))).thenAnswer(inv -> future);
        presence.disconnected(USER);
        return expiry;
    }

    private static ChatParticipant participantIn(ChatConversation conversation) {
        ChatParticipant participant = new ChatParticipant();
        participant.setConversation(conversation);
        return participant;
    }

    private static ChatConversation conversation(Long id, Long trainerId, Long clientId, Instant archivedAt) {
        ChatConversation conversation = new ChatConversation();
        conversation.setId(id);
        conversation.setTrainerId(trainerId);
        conversation.setClientId(clientId);
        conversation.setArchivedAt(archivedAt);
        return conversation;
    }
}
