package com.lifey.chat.controller;

import com.lifey.chat.dto.PresenceRequest;
import com.lifey.chat.dto.TypingRequest;
import com.lifey.chat.service.ChatStreamService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * Server-sent events for the chat (§2: SSE for server→client, plain REST for
 * client→server). Authenticated by the usual bearer token, which is why clients
 * cannot use the native {@code EventSource} — it cannot set headers — and read
 * the stream with a fetch-based reader instead (§6.2).
 */
@Tag(name = "Chat Stream", description = "Realtime chat events and presence")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/chat")
public class ChatStreamController {

    private final ChatStreamService streamService;

    @Operation(summary = "Subscribe to the caller's chat events",
            description = "One long-lived text/event-stream carrying every conversation the caller "
                    + "takes part in. Frames: `message` (carries an id, so Last-Event-ID means "
                    + "\"newest message I have\"), `read` (the peer's delivered/read cursors), "
                    + "`deleted` (a message was tombstoned — the only frame about a row the client "
                    + "already holds), `typing` (the peer is writing — the one frame with no REST "
                    + "counterpart, because it expires on its own), and `resync` when the gap is "
                    + "too large to replay. The connection is closed after "
                    + "lifey.chat.stream-timeout and the client is expected to reconnect.")
    @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream(@RequestHeader(value = "Last-Event-ID", required = false) Long lastEventId,
                             HttpServletResponse response) {
        // nginx and friends buffer proxied responses by default, which turns a
        // stream into a batch delivered whenever the buffer fills (§9).
        response.setHeader("X-Accel-Buffering", "no");
        return streamService.open(lastEventId);
    }

    @Operation(summary = "Report which thread the caller is looking at",
            description = "Drives the \"did they see it\" decision behind push (§5.1). Send the "
                    + "conversation id when a thread opens, and null when it closes or the app goes "
                    + "to the background. Held in memory with a TTL: losing it only costs an extra "
                    + "notification, never a missed message.")
    @PostMapping("/presence")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void presence(@RequestBody PresenceRequest request) {
        streamService.updatePresence(request.activeConversationId());
    }

    @Operation(summary = "Report that the caller is writing in a thread",
            description = "Sends the peer a `typing` frame, throttled server-side by "
                    + "lifey.chat.typing-throttle on top of whatever the client does. Fire and "
                    + "forget: it is dropped when the peer has no live stream and when the thread "
                    + "is archived, it never produces a push, and nothing about it is stored — the "
                    + "hint expires on the receiving client. 404 for a thread the caller is not in.")
    @PostMapping("/typing")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void typing(@Valid @RequestBody TypingRequest request) {
        streamService.typing(request.conversationId());
    }
}
