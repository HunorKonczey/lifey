package com.lifey.chat;

import com.lifey.chat.exception.AttachmentTooLargeException;
import com.lifey.chat.exception.ChatDisabledException;
import com.lifey.chat.exception.ChatRateLimitedException;
import com.lifey.chat.exception.ConversationArchivedException;
import com.lifey.chat.exception.InvalidMessageBodyException;
import com.lifey.common.exception.ApiError;
import com.lifey.common.exception.ApiErrorResponses;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.List;

/**
 * HTTP status mapping for the chat's own failures.
 *
 * <p>Lives here rather than in {@code GlobalExceptionHandler} because it was the
 * only thing in the application pointing <em>into</em> the chat
 * (docs/chat/44-chat-service-extraction-plan.md §2.2) — with these five handlers
 * moved, the dependency between the chat and the rest of the monolith is
 * one-directional. The response body still comes from the one shared builder, so
 * a chat error looks exactly like every other error in the API.
 *
 * <p>{@code @RestControllerAdvice} instances are additive: Spring picks whichever
 * one declares a handler for the thrown type, so this coexists with the global
 * advice rather than replacing it. Anything the chat throws that is not listed
 * here — {@code ResourceNotFoundException}, for instance — still falls through
 * to the global handler.
 */
@RestControllerAdvice
class ChatExceptionHandler {

    @ExceptionHandler(ConversationArchivedException.class)
    ResponseEntity<ApiError> handleConversationArchived(ConversationArchivedException ex,
                                                        HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.CONFLICT, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(InvalidMessageBodyException.class)
    ResponseEntity<ApiError> handleInvalidMessageBody(InvalidMessageBodyException ex,
                                                      HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(ChatRateLimitedException.class)
    ResponseEntity<ApiError> handleChatRateLimited(ChatRateLimitedException ex,
                                                   HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.TOO_MANY_REQUESTS, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(AttachmentTooLargeException.class)
    ResponseEntity<ApiError> handleAttachmentTooLarge(AttachmentTooLargeException ex,
                                                      HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.CONTENT_TOO_LARGE, ex.getMessage(), request, List.of(), ex);
    }

    /** Kill switch, not a client error — reads keep working, only sending is refused. */
    @ExceptionHandler(ChatDisabledException.class)
    ResponseEntity<ApiError> handleChatDisabled(ChatDisabledException ex,
                                                HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.SERVICE_UNAVAILABLE, ex.getMessage(), request, List.of(), ex);
    }
}
