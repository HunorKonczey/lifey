package com.lifey.chat.controller;

import com.lifey.chat.dto.MessageListResponse;
import com.lifey.chat.dto.MessageResponse;
import com.lifey.chat.dto.SendMessageRequest;
import com.lifey.chat.entity.ChatMessageAttachment;
import com.lifey.chat.service.ChatService;
import com.lifey.chat.service.SendMessageResult;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

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

    @Operation(summary = "Search messages in a conversation",
            description = "Case- and accent-insensitive substring match on the message text, "
                    + "newest hit first, keyset-paged by `before` exactly like the thread itself. "
                    + "Tombstoned messages never match — their text is gone. Wildcards in `q` are "
                    + "matched literally, and a term shorter than lifey.chat.search-min-length "
                    + "answers with an empty page rather than an error, because clients search as "
                    + "you type.")
    @GetMapping("/conversations/{conversationId}/messages/search")
    public MessageListResponse search(@PathVariable Long conversationId,
                                      @RequestParam("q") String query,
                                      @RequestParam(required = false) Long before,
                                      @RequestParam(required = false) Integer limit) {
        return chatService.searchMessages(conversationId, query, before, limit);
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

    @Operation(summary = "Send a message with an image",
            description = "Multipart variant of the send above: `file` is the image, `body` an "
                    + "optional caption, `clientMessageId` the same idempotency key — a replay "
                    + "returns the stored message without re-uploading the bytes. JPEG/PNG within "
                    + "`lifey.chat.attachment-max-bytes`; the server re-encodes to JPEG (metadata "
                    + "stripped) and stores a thumbnail alongside. 413 when too large, 400 when it "
                    + "isn't a decodable image.")
    @PostMapping(path = "/conversations/{conversationId}/messages",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<MessageResponse> sendWithAttachment(
            @PathVariable Long conversationId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "body", required = false) String body,
            @RequestParam("clientMessageId") String clientMessageId) {
        SendMessageResult result = chatService.sendMessage(conversationId, body, clientMessageId, file);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(result.message());
    }

    @Operation(summary = "Get a message's image",
            description = "Supports conditional GET via If-None-Match/ETag. 404 for a message "
                    + "without an image and for anyone outside the conversation alike.")
    @GetMapping("/messages/{messageId}/attachment")
    public ResponseEntity<byte[]> attachment(
            @PathVariable Long messageId,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        ChatMessageAttachment attachment = chatService.findAttachment(messageId);
        return respond(attachment, ifNoneMatch, attachment.getImage());
    }

    @Operation(summary = "Get a message image's thumbnail",
            description = "Square center-cropped JPEG for the bubble, so a thread of pictures "
                    + "doesn't download full-size images to render.")
    @GetMapping("/messages/{messageId}/attachment/thumbnail")
    public ResponseEntity<byte[]> attachmentThumbnail(
            @PathVariable Long messageId,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        ChatMessageAttachment attachment = chatService.findAttachment(messageId);
        return respond(attachment, ifNoneMatch, attachment.getThumbnail());
    }

    @Operation(summary = "Delete one of your own messages",
            description = "Tombstone, not a hard delete: the row stays so the other side keeps the "
                    + "context of their replies, but the text is cleared. 404 for anyone else's message.")
    @DeleteMapping("/messages/{messageId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long messageId) {
        chatService.deleteMessage(messageId);
    }

    /**
     * An attachment never changes once stored — a message is immutable apart
     * from its tombstone — so the creation instant is a complete ETag, and a
     * client that has the picture re-downloads it exactly never.
     */
    private ResponseEntity<byte[]> respond(ChatMessageAttachment attachment, String ifNoneMatch, byte[] body) {
        String etag = "\"" + attachment.getCreatedAt().toEpochMilli() + "\"";
        if (etag.equals(ifNoneMatch)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).build();
        }
        return ResponseEntity.ok()
                .eTag(etag)
                .contentType(MediaType.parseMediaType(attachment.getContentType()))
                .cacheControl(CacheControl.noCache().cachePrivate())
                .body(body);
    }
}
