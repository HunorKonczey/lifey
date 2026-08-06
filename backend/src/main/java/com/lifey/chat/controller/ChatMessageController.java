package com.lifey.chat.controller;

import com.lifey.chat.dto.MessageListResponse;
import com.lifey.chat.dto.MessageResponse;
import com.lifey.chat.dto.SendMessageRequest;
import com.lifey.chat.service.ChatService;
import com.lifey.chat.service.SendMessageResult;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Chat Messages", description = "Reading, sending and tombstoning messages")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/chat")
public class ChatMessageController {

    private final ChatService chatService;

    @Operation(summary = "List messages in a conversation",
            description = "Keyset paging by id, always answered newest-first. `before` walks into "
                    + "history (scroll up); `after` fills the gap above a known id after the client "
                    + "was offline and wins if both are given. Offset paging is deliberately not "
                    + "offered: a growing thread would shift rows between pages.")
    @GetMapping("/conversations/{conversationId}/messages")
    public MessageListResponse list(@PathVariable Long conversationId,
                                    @RequestParam(required = false) Long before,
                                    @RequestParam(required = false) Long after,
                                    @RequestParam(required = false) Integer limit) {
        return chatService.listMessages(conversationId, before, after, limit);
    }

    @Operation(summary = "Send a message",
            description = "Idempotent on clientMessageId: 201 for a new message, 200 with the stored "
                    + "one when the same id is replayed — which is what makes the mobile outbox's "
                    + "blind retry safe. 409 if the thread is archived, 429 over the rate limit.")
    @PostMapping("/conversations/{conversationId}/messages")
    public ResponseEntity<MessageResponse> send(@PathVariable Long conversationId,
                                                @Valid @RequestBody SendMessageRequest request) {
        SendMessageResult result = chatService.sendMessage(conversationId, request);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(result.message());
    }

    @Operation(summary = "Delete one of your own messages",
            description = "Tombstone, not a hard delete: the row stays so the other side keeps the "
                    + "context of their replies, but the text is cleared. 404 for anyone else's message.")
    @DeleteMapping("/messages/{messageId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long messageId) {
        chatService.deleteMessage(messageId);
    }
}
