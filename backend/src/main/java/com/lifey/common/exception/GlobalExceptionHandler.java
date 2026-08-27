package com.lifey.common.exception;

import com.lifey.auth.exception.*;
import com.lifey.billing.exception.InvalidReceiptException;
import com.lifey.billing.exception.SeatLimitExceededException;
import com.lifey.billing.exception.SubscriptionAlreadyLinkedException;
import com.lifey.superadmin.exception.CannotModifySelfException;
import com.lifey.superadmin.exception.RoleNotManageableException;
import com.lifey.trainer.exception.AlreadyClientException;
import com.lifey.trainer.exception.CalendarRangeExceededException;
import com.lifey.trainer.exception.EmptyRecurrenceException;
import com.lifey.trainer.exception.InvalidProgramStructureException;
import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.exception.InviteRateLimitedException;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.trainer.exception.OccurrenceNotCancellableException;
import com.lifey.trainer.exception.ProgramAssignmentNotFoundException;
import com.lifey.trainer.exception.ProgramNotFoundException;
import com.lifey.trainer.exception.ProgramStartDateInvalidException;
import com.lifey.trainer.exception.ScheduleHorizonExceededException;
import com.lifey.trainer.exception.ScheduleInPastException;
import com.lifey.trainer.exception.ScheduleNotFoundException;
import com.lifey.trainer.exception.SelfInviteException;
import com.lifey.trainer.exception.UserNotFoundForInviteException;
import com.lifey.trainer.request.exception.TrainerRequestAlreadyDecidedException;
import com.lifey.workout.session.cardio.InvalidCardioRequestException;
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
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

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

    @ExceptionHandler(InvalidImageException.class)
    public ResponseEntity<ApiError> handleInvalidImage(InvalidImageException ex, HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ApiError> handleMaxUploadSize(MaxUploadSizeExceededException ex,
                                                         HttpServletRequest request) {
        return build(HttpStatus.CONTENT_TOO_LARGE,
                "Uploaded file exceeds the maximum allowed size", request, List.of(), ex);
    }

    @ExceptionHandler({InviteNotFoundException.class, UserNotFoundForInviteException.class})
    public ResponseEntity<ApiError> handleTrainerNotFound(RuntimeException ex, HttpServletRequest request) {
        return build(HttpStatus.NOT_FOUND, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(AlreadyClientException.class)
    public ResponseEntity<ApiError> handleAlreadyClient(AlreadyClientException ex, HttpServletRequest request) {
        return build(HttpStatus.CONFLICT, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(SelfInviteException.class)
    public ResponseEntity<ApiError> handleSelfInvite(SelfInviteException ex, HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(InviteRateLimitedException.class)
    public ResponseEntity<ApiError> handleInviteRateLimited(InviteRateLimitedException ex, HttpServletRequest request) {
        return build(HttpStatus.TOO_MANY_REQUESTS, ex.getMessage(), request, List.of(), ex);
    }

    /** 64 §4.3, 63 §7.6 — SEAT_LIMIT_EXCEEDED: over the seat limit, or billing isn't in an entitling state. */
    @ExceptionHandler(SeatLimitExceededException.class)
    public ResponseEntity<ApiError> handleSeatLimitExceeded(SeatLimitExceededException ex, HttpServletRequest request) {
        return build(HttpStatus.CONFLICT, ex.getMessage(), request, List.of(), ex);
    }

    /** 64 §6.1, 63 §7.7: SUBSCRIPTION_ALREADY_LINKED — a store purchase's identity already belongs to another account. */
    @ExceptionHandler(SubscriptionAlreadyLinkedException.class)
    public ResponseEntity<ApiError> handleSubscriptionAlreadyLinked(SubscriptionAlreadyLinkedException ex, HttpServletRequest request) {
        return build(HttpStatus.CONFLICT, ex.getMessage(), request, List.of(), ex);
    }

    /** 64 §6.1: INVALID_RECEIPT — a store purchase's signature could not be verified. */
    @ExceptionHandler(InvalidReceiptException.class)
    public ResponseEntity<ApiError> handleInvalidReceipt(InvalidReceiptException ex, HttpServletRequest request) {
        return build(HttpStatus.UNPROCESSABLE_CONTENT, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(NotYourClientException.class)
    public ResponseEntity<ApiError> handleNotYourClient(NotYourClientException ex, HttpServletRequest request) {
        return build(HttpStatus.FORBIDDEN, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler({ScheduleInPastException.class, EmptyRecurrenceException.class, CalendarRangeExceededException.class})
    public ResponseEntity<ApiError> handleScheduleValidation(RuntimeException ex, HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(ScheduleNotFoundException.class)
    public ResponseEntity<ApiError> handleScheduleNotFound(ScheduleNotFoundException ex, HttpServletRequest request) {
        return build(HttpStatus.NOT_FOUND, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(ScheduleHorizonExceededException.class)
    public ResponseEntity<ApiError> handleScheduleHorizonExceeded(ScheduleHorizonExceededException ex, HttpServletRequest request) {
        return build(HttpStatus.UNPROCESSABLE_CONTENT, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(OccurrenceNotCancellableException.class)
    public ResponseEntity<ApiError> handleOccurrenceNotCancellable(OccurrenceNotCancellableException ex, HttpServletRequest request) {
        return build(HttpStatus.CONFLICT, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(ProgramNotFoundException.class)
    public ResponseEntity<ApiError> handleProgramNotFound(ProgramNotFoundException ex, HttpServletRequest request) {
        return build(HttpStatus.NOT_FOUND, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(InvalidProgramStructureException.class)
    public ResponseEntity<ApiError> handleInvalidProgramStructure(InvalidProgramStructureException ex, HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(ProgramAssignmentNotFoundException.class)
    public ResponseEntity<ApiError> handleProgramAssignmentNotFound(ProgramAssignmentNotFoundException ex, HttpServletRequest request) {
        return build(HttpStatus.NOT_FOUND, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(ProgramStartDateInvalidException.class)
    public ResponseEntity<ApiError> handleProgramStartDateInvalid(ProgramStartDateInvalidException ex, HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler({RoleNotManageableException.class, CannotModifySelfException.class})
    public ResponseEntity<ApiError> handleRoleManagementRejection(RuntimeException ex, HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    /** 66 §2 — a decision (approve/reject) was attempted on a request that isn't PENDING any more. */
    @ExceptionHandler(TrainerRequestAlreadyDecidedException.class)
    public ResponseEntity<ApiError> handleTrainerRequestAlreadyDecided(TrainerRequestAlreadyDecidedException ex, HttpServletRequest request) {
        return build(HttpStatus.CONFLICT, ex.getMessage(), request, List.of(), ex);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiError> handleAccessDenied(AccessDeniedException ex, HttpServletRequest request) {
        return build(HttpStatus.FORBIDDEN, "Access denied", request, List.of(), ex);
    }

    @ExceptionHandler(InvalidCardioRequestException.class)
    public ResponseEntity<ApiError> handleInvalidCardioRequest(InvalidCardioRequestException ex, HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, ex.getMessage(), request, List.of(), ex);
    }

    /**
     * A path that matches no handler. Without this it falls through to the
     * catch-all below and becomes a 500 — an unknown URL reported as "the server
     * is broken", which sends anyone debugging it looking in the wrong place.
     * It also matters for the chat: this application no longer serves
     * /api/v1/chat/**, so a client still pointed here should get a clean 404
     * rather than a 500 that looks like an outage
     * (docs/chat/44-chat-service-extraction-plan.md §10.4).
     */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiError> handleNoResource(NoResourceFoundException ex, HttpServletRequest request) {
        return build(HttpStatus.NOT_FOUND, "No endpoint " + request.getMethod() + " " + request.getRequestURI(),
                request, List.of(), ex);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleUnexpected(Exception ex, HttpServletRequest request) {
        return build(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred", request, List.of(), ex);
    }

    private ResponseEntity<ApiError> build(HttpStatus status, String message,
                                           HttpServletRequest request, List<String> details, Exception ex) {
        return ApiErrorResponses.build(status, message, request, details, ex);
    }
}
