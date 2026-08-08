package com.lifey.common.exception;

import com.lifey.auth.InvalidTokenException;
import com.lifey.auth.TokenExpiredException;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.List;

/**
 * The generic half of this service's error handling. The chat's own failures —
 * archived thread, rate limit, kill switch and friends — are mapped by
 * {@code com.lifey.chat.ChatExceptionHandler}, which travelled with the chat
 * from the monolith unchanged.
 *
 * <p>Same {@link ApiError} shape as {@code lifey-api} produces, deliberately:
 * the mobile and web clients parse one error format, and after the cutover they
 * are talking to both services in the same session (§7). A chat 404 that looked
 * different from an API 404 would be a client bug waiting to happen.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiError> handleNotFound(ResourceNotFoundException ex, HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.NOT_FOUND, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex,
                                                     HttpServletRequest request) {
        List<String> details = ex.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .toList();
        return ApiErrorResponses.build(HttpStatus.BAD_REQUEST, "Validation failed", request, details, ex);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiError> handleUnreadable(HttpMessageNotReadableException ex,
                                                     HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.BAD_REQUEST,
                "Malformed or unreadable request body", request, List.of(), ex);
    }

    /** An upload that will not decode — the attachment pipeline's validation (§18.2). */
    @ExceptionHandler(InvalidImageException.class)
    public ResponseEntity<ApiError> handleInvalidImage(InvalidImageException ex, HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    /**
     * The container-wide multipart cap. Sits <em>above</em> the chat's own
     * {@code lifey.chat.attachment-max-bytes}, so in practice a caller hits
     * {@code AttachmentTooLargeException} first; this is the backstop for a
     * body so large it never reaches the controller.
     */
    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ApiError> handleMaxUploadSize(MaxUploadSizeExceededException ex,
                                                        HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.CONTENT_TOO_LARGE,
                "Uploaded file exceeds the maximum allowed size", request, List.of(), ex);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ApiError> handleDataIntegrity(DataIntegrityViolationException ex,
                                                        HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.CONFLICT,
                "Operation violates a data integrity constraint (the resource may still be referenced)",
                request, List.of(), ex);
    }

    /**
     * A token problem reached a controller rather than the filter chain. The
     * message distinguishes expired from invalid, which is what tells the client
     * to refresh at {@code lifey-api} and retry instead of signing the user out
     * (§7.2).
     */
    @ExceptionHandler({InvalidTokenException.class, TokenExpiredException.class, AuthenticationException.class})
    public ResponseEntity<ApiError> handleAuthentication(RuntimeException ex, HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.UNAUTHORIZED, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiError> handleAccessDenied(AccessDeniedException ex, HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.FORBIDDEN, "Access denied", request, List.of(), ex);
    }

    /**
     * A path that matches no handler. Without this it falls through to the
     * catch-all below and becomes a 500 — an unknown URL reported as "the server
     * is broken", which sends anyone debugging it looking in the wrong place.
     * It also matters at the chat cutover: once CHAT_LOCAL_ENABLED is off, a
     * client still pointed here should get a clean 404
     * (docs/chat/44-chat-service-extraction-plan.md §10.3).
     */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiError> handleNoResource(NoResourceFoundException ex, HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.NOT_FOUND, "No endpoint " + request.getMethod() + " " + request.getRequestURI(),
                request, List.of(), ex);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleUnexpected(Exception ex, HttpServletRequest request) {
        return ApiErrorResponses.build(HttpStatus.INTERNAL_SERVER_ERROR,
                "An unexpected error occurred", request, List.of(), ex);
    }
}
