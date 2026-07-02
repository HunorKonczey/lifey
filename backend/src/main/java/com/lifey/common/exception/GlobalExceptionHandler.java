package com.lifey.common.exception;

import com.lifey.auth.exception.*;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.List;

/**
 * Centralized exception handling translating exceptions into {@link ApiError} responses.
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiError> handleNotFound(ResourceNotFoundException ex,
                                                   HttpServletRequest request) {
        return build(HttpStatus.NOT_FOUND, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(DuplicateResourceException.class)
    public ResponseEntity<ApiError> handleDuplicate(DuplicateResourceException ex,
                                                    HttpServletRequest request) {
        return build(HttpStatus.CONFLICT, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex,
                                                     HttpServletRequest request) {
        List<String> details = ex.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .toList();
        return build(HttpStatus.BAD_REQUEST, "Validation failed", request, details, ex);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiError> handleUnreadable(HttpMessageNotReadableException ex,
                                                     HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, "Malformed or unreadable request body", request, List.of(), ex);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ApiError> handleDataIntegrity(DataIntegrityViolationException ex,
                                                        HttpServletRequest request) {
        return build(HttpStatus.CONFLICT,
                "Operation violates a data integrity constraint (the resource may still be referenced)",
                request, List.of(), ex);
    }

    @ExceptionHandler({InvalidCredentialsException.class, InvalidTokenException.class,
            TokenExpiredException.class, TokenRevokedException.class, InvalidSocialTokenException.class,
            AuthenticationException.class})
    public ResponseEntity<ApiError> handleAuthentication(RuntimeException ex, HttpServletRequest request) {
        return build(HttpStatus.UNAUTHORIZED, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(UnverifiedEmailException.class)
    public ResponseEntity<ApiError> handleUnverifiedEmail(UnverifiedEmailException ex, HttpServletRequest request) {
        return build(HttpStatus.FORBIDDEN, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(InvalidResetCodeException.class)
    public ResponseEntity<ApiError> handleInvalidResetCode(InvalidResetCodeException ex, HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler({IncorrectPasswordException.class, SamePasswordException.class})
    public ResponseEntity<ApiError> handlePasswordChangeRejection(RuntimeException ex, HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiError> handleAccessDenied(AccessDeniedException ex, HttpServletRequest request) {
        return build(HttpStatus.FORBIDDEN, "Access denied", request, List.of(), ex);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleUnexpected(Exception ex, HttpServletRequest request) {
        return build(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred", request, List.of(), ex);
    }

    private ResponseEntity<ApiError> build(HttpStatus status, String message,
                                           HttpServletRequest request, List<String> details, Exception ex) {
        if (status.is5xxServerError()) {
            log.error("{} {} -> {} {}", request.getMethod(), request.getRequestURI(), status.value(), message, ex);
        } else {
            log.warn("{} {} -> {} {}", request.getMethod(), request.getRequestURI(), status.value(), message, ex);
        }
        ApiError body = new ApiError(
                Instant.now(),
                status.value(),
                status.getReasonPhrase(),
                message,
                request.getRequestURI(),
                details
        );
        return ResponseEntity.status(status).body(body);
    }
}
