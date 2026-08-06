package com.lifey.chat.service;

import com.lifey.chat.ChatMapper;
import com.lifey.chat.ChatMessageStoredEvent;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.repository.ChatMessageRepository;
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
 * <p><b>What this iteration deliberately does not do.</b> The full §5.2 ladder
 * has four more gates before the send: presence ("is the recipient looking at
 * this very thread"), quiet hours, per-thread mute, and the coalescing window.
 * Presence needs the SSE registry (I4) and the other three arrive in I5. Until
 * then this fails open towards the push — an extra notification is a smaller
 * failure than a missed message.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ChatNotificationServiceImpl implements ChatNotificationService {

    private static final int PUSH_BODY_MAX_LENGTH = 120;

    private final ChatMessageRepository messageRepository;
    private final UserSettingsRepository userSettingsRepository;
    private final PushService pushService;

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

        Optional<UserSettings> settings = userSettingsRepository.findByUserId(recipient.getId());
        if (!settings.map(UserSettings::isChatPushEnabled).orElse(true)) {
            return;
        }
        boolean hungarian = settings.map(s -> s.getLanguage() == LanguagePreference.HUNGARIAN).orElse(false);

        // Counted rather than tracked per-push: the cursor is the truth, so the
        // aggregated copy stays correct even after a push was dropped or the
        // recipient read part of the thread elsewhere (§5.3).
        long unread = messageRepository.countUnread(conversation.getId(), recipient.getId());

        pushService.sendToUser(recipient.getId(), buildMessage(message, sender, unread, hungarian));
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
        return new PushMessage(title, body, data);
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
