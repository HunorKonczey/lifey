package com.lifey.chat;

import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import com.lifey.chat.service.ChatQuietHours;
import com.lifey.chat.spi.ChatMailSender;
import com.lifey.chat.spi.ChatNotificationPreferences;
import com.lifey.chat.spi.ChatPushNotification;
import com.lifey.chat.spi.ChatPushPrefs;
import com.lifey.chat.spi.ChatPushSender;
import com.lifey.chat.spi.ChatUser;
import com.lifey.chat.spi.ChatUserDirectory;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The "still not read" safety net (docs/chat/40-trainer-chat-plan.md §5.4).
 *
 * <p>Every gate in {@code ChatNotificationServiceImpl} is a reason not to
 * interrupt someone <em>right now</em> — quiet hours, a mute, the coalescing
 * window — and every one of them can end with a message sitting unread that the
 * recipient never heard about. Same for a push that was simply dropped on the
 * way. This job is what comes back for those, and it is deliberately blunt: one
 * summary notification per user, at most {@code reminderDailyCap} a day.
 *
 * <p>Runs every five minutes because the decision is per-user-local: a user
 * whose quiet hours have just ended should be reminded soon after, not at the
 * next daily tick. Each run only acts on users who are actually due.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ChatUnreadReminderJob {

    private final ChatParticipantRepository participantRepository;
    private final ChatMessageRepository messageRepository;
    private final ChatNotificationPreferences preferences;
    private final ChatUserDirectory userDirectory;
    private final ChatPushSender pushSender;
    private final ChatMailSender mailSender;
    private final ChatProperties properties;
    private final ChatMetrics metrics;
    private final Clock clock;

    @Scheduled(cron = "${lifey.jobs.chat-unread-reminder.cron}")
    @Transactional
    public void sendDueReminders() {
        Instant now = clock.instant();
        Instant threshold = now.minus(properties.reminderAfter());

        // Grouped per user, because the reminder is one notification about
        // everything they have missed — not one per thread, which is exactly
        // the spam this job exists to avoid.
        Map<Long, List<ChatParticipant>> byUser = new LinkedHashMap<>();
        for (ChatParticipant participant : participantRepository.findReminderCandidates(threshold)) {
            byUser.computeIfAbsent(participant.getUserId(), id -> new ArrayList<>()).add(participant);
        }

        for (List<ChatParticipant> threads : byUser.values()) {
            try {
                remindIfDue(threads, now);
            } catch (RuntimeException ex) {
                // One user's bad state must not stop the sweep for everyone else.
                log.error("Chat unread reminder failed for user {}", threads.getFirst().getUserId(), ex);
            }
        }
    }

    private void remindIfDue(List<ChatParticipant> threads, Instant now) {
        Long userId = threads.getFirst().getUserId();
        ChatPushPrefs prefs = preferences.load(userId);
        if (!prefs.pushEnabled()) {
            return;
        }
        // Quiet hours push the reminder out rather than cancelling it: the next
        // tick after the window ends finds the same unread messages and sends.
        if (ChatQuietHours.isQuiet(prefs, now)) {
            return;
        }
        if (isOverDailyCap(userId, now)) {
            return;
        }

        // A muted thread stays muted here too — the reminder is a second
        // attempt at the same notification, not a way around the mute.
        List<ChatParticipant> audible = threads.stream()
                .filter(participant -> participant.getMutedUntil() == null
                        || !participant.getMutedUntil().isAfter(now))
                .toList();
        if (audible.isEmpty()) {
            return;
        }

        long unread = 0;
        Instant oldestUnnotified = null;
        for (ChatParticipant participant : audible) {
            unread += messageRepository.countUnread(participant.getConversation().getId(), userId);
            Instant notified = participant.getLastNotifiedAt();
            if (oldestUnnotified == null || notified == null || notified.isBefore(oldestUnnotified)) {
                oldestUnnotified = notified;
            }
        }
        if (unread == 0) {
            return;
        }

        boolean hungarian = prefs.hungarian();
        String peerName = peerNameOf(audible.getFirst(), userId);
        boolean singleThread = audible.size() == 1;

        if (shouldEmailInstead(userId, oldestUnnotified, now)) {
            mailSender.sendUnreadChatEmail(userId, unread, peerName);
            metrics.reminderSent("email");
        } else {
            pushSender.send(userId, new ChatPushNotification(
                    hungarian ? "Olvasatlan üzeneteid vannak" : "You have unread messages",
                    reminderBody(unread, singleThread ? peerName : null, hungarian),
                    Map.of("type", "chat_reminder"),
                    // One reminder row that replaces the previous one, rather
                    // than a new line in the notification centre every day.
                    "chat-reminder"));
            metrics.reminderSent("push");
        }

        markReminded(userId, now);
    }

    /**
     * The cap is per user, so it has to be read across <em>all</em> of their
     * threads — a reminder sent about thread A this morning must also silence
     * thread B this afternoon.
     */
    private boolean isOverDailyCap(Long userId, Instant now) {
        if (properties.reminderDailyCap() <= 0) {
            return true;
        }
        Instant dayAgo = now.minus(Duration.ofDays(1));
        return participantRepository.findAllForUser(userId).stream()
                .map(ChatParticipant::getLastRemindedAt)
                .anyMatch(remindedAt -> remindedAt != null && remindedAt.isAfter(dayAgo));
    }

    /** Written to every thread, since the cap it feeds is per user. */
    private void markReminded(Long userId, Instant now) {
        participantRepository.findAllForUser(userId)
                .forEach(participant -> participant.setLastRemindedAt(now));
    }

    /**
     * §5.5 — the email is for the one case a push cannot reach: no registered
     * device at all. Flag-gated and additionally time-gated, because a mail
     * about an unread chat message reads as spam far more easily than a push.
     */
    private boolean shouldEmailInstead(Long userId, Instant oldestNotifiedAt, Instant now) {
        if (!properties.emailFallbackEnabled()) {
            return false;
        }
        if (pushSender.hasRegisteredDevice(userId)) {
            return false;
        }
        // Never notified at all counts as "long enough ago" — there is no push
        // timestamp to wait past when no push was ever attempted.
        return oldestNotifiedAt == null
                || oldestNotifiedAt.isBefore(now.minus(properties.emailFallbackAfter()));
    }

    private static String reminderBody(long unread, String peerName, boolean hungarian) {
        if (peerName == null) {
            return hungarian
                    ? unread + " olvasatlan üzeneted van"
                    : "You have " + unread + " unread messages";
        }
        return hungarian
                ? unread + " olvasatlan üzeneted van tőle: " + peerName
                : "You have " + unread + " unread messages from " + peerName;
    }

    /** Empty rather than absent when the peer cannot be resolved: a reminder
     * without a name is still worth sending, and this runs unattended. */
    private String peerNameOf(ChatParticipant participant, Long userId) {
        Long peerId = participant.getConversation().peerOf(userId);
        return userDirectory.find(peerId).map(ChatUser::displayName).orElse("");
    }
}
