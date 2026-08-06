package com.lifey.chat;

import com.lifey.chat.service.ChatService;
import com.lifey.trainer.TrainerClientRevokedEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Freezes a pair's thread when their relationship ends
 * (docs/chat/40-trainer-chat-plan.md §1.3/1): the history stays readable to
 * both sides forever, but new messages are rejected.
 *
 * <p>Plain {@code @EventListener}, not {@code @TransactionalEventListener} —
 * same reasoning as {@code ScheduleCancellationListener}: archiving has to be
 * part of the revoke transaction, otherwise a rolled-back revoke would leave a
 * thread archived that is in fact still live.
 */
@Component
@RequiredArgsConstructor
class ChatArchiveListener {

    private final ChatService chatService;

    @EventListener
    void onTrainerClientRevoked(TrainerClientRevokedEvent event) {
        chatService.archiveForPair(event.trainerId(), event.clientId());
    }
}
