package com.lifey.internal;

import com.lifey.trainer.TrainerClientRevokedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.web.client.RestClient;

/**
 * Tells {@code lifey-chat} that a trainer-client relationship has ended, so it
 * can freeze the pair's thread (docs/chat/44-chat-service-extraction-plan.md
 * §5.4, layer 2).
 *
 * <p><b>{@code AFTER_COMMIT}, unlike the in-process listener it replaces.</b>
 * {@code ChatArchiveListener} archives inside the revoke transaction, which is
 * right when both live in one database session: a rolled-back revoke must not
 * leave a thread archived. An HTTP call cannot join that transaction, so the
 * choice is between telling the chat about a revoke that might roll back, and
 * telling it only about revokes that actually happened. This takes the second.
 *
 * <p><b>This call can be lost</b> — the chat service restarting, a network
 * blip — and that is accepted rather than retried here. Two things cover it:
 * the chat re-checks the relationship on every write (§5.4 layer 1), so a lost
 * webhook cannot let anyone talk in a dead thread; and the chat's daily
 * reconciliation sweep (layer 3) sets the flag it missed. Adding a retry queue
 * to this listener would be a third mechanism for a problem two already solve.
 */
@Slf4j
@Component
@RequiredArgsConstructor
class ChatRevokeWebhook {

    private final RestClient chatServiceRestClient;
    private final InternalApiProperties properties;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onTrainerClientRevoked(TrainerClientRevokedEvent event) {
        if (!properties.hasChatService()) {
            // The chat still runs in this application; ChatArchiveListener has
            // already done the archiving, in the transaction.
            return;
        }
        try {
            chatServiceRestClient.post()
                    .uri("/internal/relationships/revoked")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(new RevokeNotification(event.trainerId(), event.clientId()))
                    .retrieve()
                    .toBodilessEntity();
        } catch (RuntimeException ex) {
            // Never propagate: the revoke is committed and the user has been
            // told it worked. Ids only.
            log.error("Chat revoke webhook failed for trainer {} / client {}",
                    event.trainerId(), event.clientId(), ex);
        }
    }

    /**
     * Pair-based rather than by {@code trainerClientId}, because that is the
     * shape of both the event and the chat's {@code archiveForPair} — and
     * because a re-invited client can hold several historical threads, all of
     * which the chat resolves for itself.
     */
    private record RevokeNotification(Long trainerId, Long clientId) {
    }
}
