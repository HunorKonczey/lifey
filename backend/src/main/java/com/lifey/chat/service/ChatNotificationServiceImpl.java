package com.lifey.chat.service;

import com.lifey.chat.ChatMapper;
import com.lifey.chat.ChatMessageStoredEvent;
import com.lifey.chat.ChatProperties;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.user.User;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;

/**
 * Sends the "you have a new message" push (docs/chat/40-trainer-chat-plan.md
 * §5.2), following the same shape as {@code SessionCommentServiceImpl}:
 * settings check → language-dependent copy → {@code PushService}.
 *
 * <p><b>Symmetric by design.</b> The trainer gets pushed exactly like the
 * client — the plan's §11/1 decision is one switch and one mental model for
 * both roles, so nothing here branches on who is on which side.
 *
 * <p><b>The full §5.2 ladder, in order.</b> Each gate is a reason <em>not</em>
 * to interrupt someone, and they are cheap-first: presence, the master switch,
 * quiet hours, the per-thread mute, then the coalescing window. Anything that
 * gets past all five is a notification worth sending, and it records
 * {@code lastNotifiedAt} so the next one has a window to respect.
 *
 * <p>Nothing here suppresses the <em>message</em> — a gate only ever silences
 * the notification, and {@code ChatUnreadReminderJob} is the safety net that
 * comes back for anything left unread.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ChatNotificationServiceImpl implements ChatNotificationService {

    private static final int PUSH_BODY_MAX_LENGTH = 120;

    private final ChatMessageRepository messageRepository;
    private final ChatParticipantRepository participantRepository;
    private final UserSettingsRepository userSettingsRepository;
    private final PushService pushService;
    private final ChatEventBus eventBus;
    private final ChatPresenceRegistry presenceRegistry;
    private final ChatProperties properties;
    private final Clock clock;

    @Override
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onMessageStored(ChatMessageStoredEvent event) {
        try {
            notify(event.messageId());
        } catch (RuntimeException ex) {
            // The message is already committed and visible in the API; a
            // notification problem must not propagate out of the listener and
            // surface to the sender as a failure. Log ids only, never the body.
            log.error("Chat push failed for message {}", event.messageId(), ex);
        }
    }

    private void notify(Long messageId) {
        ChatMessage message = messageRepository.findById(messageId).orElse(null);
        if (message == null) {
            return;
        }
        ChatConversation conversation = message.getConversation();
        User sender = message.getSender();
        User recipient = conversation.getTrainer().getId().equals(sender.getId())
                ? conversation.getClient()
                : conversation.getTrainer();
        Instant now = clock.instant();

        // §5.1 — "seen": a live stream plus presence on this exact thread means
        // the message is already on their screen. Both halves are required: a
        // stale presence entry without a connection would silence a push for
        // someone who is not there, and a connection alone says nothing about
        // which thread they are looking at.
        if (eventBus.isConnected(recipient.getId())
                && presenceRegistry.isViewing(recipient.getId(), conversation.getId())) {
            return;
        }

        Optional<UserSettings> settings = userSettingsRepository.findByUserId(recipient.getId());
        if (!settings.map(UserSettings::isChatPushEnabled).orElse(true)) {
            return;
        }

        // Quiet hours and mute are both "not now" rather than "not at all" —
        // the message stays unread, and §5.4's reminder is what eventually
        // surfaces it once the window or the mute has passed.
        if (ChatQuietHours.isQuiet(recipient, settings.orElse(null), now)) {
            return;
        }

        ChatParticipant participant = participantRepository
                .findByConversationIdAndUserId(conversation.getId(), recipient.getId())
                .orElse(null);
        if (isMuted(participant, now) || isWithinCoalesceWindow(participant, now)) {
            return;
        }

        boolean hungarian = settings.map(s -> s.getLanguage() == LanguagePreference.HUNGARIAN).orElse(false);

        // Counted rather than tracked per-push: the cursor is the truth, so the
        // aggregated copy stays correct even after a push was dropped or the
        // recipient read part of the thread elsewhere (§5.3).
        long unread = messageRepository.countUnread(conversation.getId(), recipient.getId());

        pushService.sendToUser(recipient.getId(), buildMessage(message, sender, unread, hungarian));

        if (participant != null) {
            participant.setLastNotifiedAt(now);
        }
    }

    private static boolean isMuted(ChatParticipant participant, Instant now) {
        return participant != null
                && participant.getMutedUntil() != null
                && participant.getMutedUntil().isAfter(now);
    }

    /**
     * §5.3 — one push per thread per window. A fast typist's five messages are
     * one interruption, and the recipient loses nothing: the count in the body
     * is read from the cursor when the next push does go out, so it is always
     * the true number of unread messages rather than the number since the last
     * notification.
     */
    private boolean isWithinCoalesceWindow(ChatParticipant participant, Instant now) {
        Duration window = properties.pushCoalesceWindow();
        if (participant == null || participant.getLastNotifiedAt() == null || window == null) {
            return false;
        }
        return participant.getLastNotifiedAt().isAfter(now.minus(window));
    }

    private static PushMessage buildMessage(ChatMessage message, User sender, long unread, boolean hungarian) {
        String title = ChatMapper.displayName(sender);
        String body = unread > 1
                ? aggregatedBody(unread, hungarian)
                : truncate(message.getBody());
        Map<String, String> data = Map.of(
                "type", "chat_message",
                "conversationId", String.valueOf(message.getConversation().getId()),
                "messageId", String.valueOf(message.getId())
        );
        return new PushMessage(title, body, data, collapseKey(message.getConversation().getId()));
    }

    /** One row per thread in the OS notification centre (§5.3). */
    static String collapseKey(Long conversationId) {
        return "chat-" + conversationId;
    }

    private static String aggregatedBody(long unread, boolean hungarian) {
        return hungarian ? unread + " új üzenet" : unread + " new messages";
    }

    private static String truncate(String body) {
        if (body == null) {
            return "";
        }
        return body.length() > PUSH_BODY_MAX_LENGTH
                ? body.substring(0, PUSH_BODY_MAX_LENGTH - 1) + "…"
                : body;
    }
}
