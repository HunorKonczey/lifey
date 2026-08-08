package com.lifey.internal;

import com.lifey.chat.service.ChatService;
import io.swagger.v3.oas.annotations.Hidden;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * What replaces {@code ChatArchiveListener} once the chat no longer shares a
 * process — and a transaction — with the trainer module
 * (docs/chat/44-chat-service-extraction-plan.md §5.4, layer 2).
 *
 * <p><b>Idempotent.</b> {@code archiveForPair} only touches threads that are not
 * already archived, so a retried or duplicated webhook is a no-op, and so is one
 * that arrives after the daily reconciliation sweep already did the work. That
 * matters because the sender does not retry: it logs and moves on.
 *
 * <p>Never the whole story on its own. A lost call here cannot let anyone write
 * into a dead thread — {@code ChatServiceImpl} re-checks the relationship on
 * every send (layer 1) — and the sweep (layer 3) sets the flag eventually. This
 * endpoint is what makes it <em>prompt</em>.
 */
@Hidden // not part of the public API surface springdoc advertises
@Slf4j
@RestController
@RequestMapping("/internal/relationships")
@RequiredArgsConstructor
class InternalRelationshipController {

    private final ChatService chatService;

    @PostMapping("/revoked")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void revoked(@Valid @RequestBody RevokeNotification notification) {
        log.info("Archiving chat threads for revoked relationship: trainer {} / client {}",
                notification.trainerId(), notification.clientId());
        chatService.archiveForPair(notification.trainerId(), notification.clientId());
    }

    /**
     * Pair-based rather than by {@code trainerClientId}: that is the shape of
     * the monolith's revoke event, and a re-invited client can hold several
     * historical threads — all of which need freezing, and all of which this
     * service can find for itself.
     */
    record RevokeNotification(@NotNull Long trainerId, @NotNull Long clientId) {
    }
}
