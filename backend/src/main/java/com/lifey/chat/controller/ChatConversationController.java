package com.lifey.chat.controller;

import com.lifey.chat.dto.ConversationListResponse;
import com.lifey.chat.dto.ConversationResponse;
import com.lifey.chat.dto.OpenConversationRequest;
import com.lifey.chat.dto.ReadReceiptRequest;
import com.lifey.chat.service.ChatService;
import com.lifey.chat.service.OpenConversationResult;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Lives under {@code /api/v1/chat/**}, deliberately not {@code /api/v1/trainer/**}:
 * that prefix is gated on {@code ROLE_TRAINER} by {@code SecurityConfig}, and
 * both sides of a conversation use these endpoints. Authorization comes from
 * participation in the thread, never from a role (docs/chat/40-trainer-chat-plan.md §4).
 */
@Tag(name = "Chat Conversations", description = "Trainer <-> client threads; same endpoints for both roles")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/chat/conversations")
public class ChatConversationController {

    private final ChatService chatService;

    @Operation(summary = "List the caller's conversations",
            description = "Newest activity first. Role-agnostic: a trainer who also has a trainer "
                    + "of their own sees both kinds of thread here, distinguished by peer.role.")
    @GetMapping
    public ConversationListResponse list() {
        return chatService.getConversations();
    }

    @Operation(summary = "Open the conversation for a trainer-client relationship",
            description = "Lazy-create: 200 with the existing thread, 201 if it was just created. "
                    + "404 unless the relationship is ACTIVE and the caller is one of its two sides.")
    @PostMapping
    public ResponseEntity<ConversationResponse> open(@Valid @RequestBody OpenConversationRequest request) {
        return respond(chatService.openConversation(request.trainerClientId()));
    }

    @Operation(summary = "Open the conversation with a given user",
            description = "Same as POST /conversations but keyed on the peer's user id — the entry "
                    + "point mobile has, where the relationship id isn't in hand.")
    @PostMapping("/with-user/{userId}")
    public ResponseEntity<ConversationResponse> openWithUser(@PathVariable Long userId) {
        return respond(chatService.openConversationWithUser(userId));
    }

    @Operation(summary = "Acknowledge messages as read",
            description = "Moves the caller's read cursor to lastReadMessageId. Monotonic and "
                    + "clamped to the newest stored message, so a stale or racing client is harmless.")
    @PostMapping("/{conversationId}/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markRead(@PathVariable Long conversationId, @Valid @RequestBody ReadReceiptRequest request) {
        chatService.markRead(conversationId, request.lastReadMessageId());
    }

    private static ResponseEntity<ConversationResponse> respond(OpenConversationResult result) {
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(result.conversation());
    }
}
