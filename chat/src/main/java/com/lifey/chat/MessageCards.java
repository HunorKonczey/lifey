package com.lifey.chat;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.lifey.chat.dto.MessageCard;
import com.lifey.chat.exception.InvalidMessageCardException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Duration;
import java.time.Instant;

/**
 * The rules and the storage format of a message card
 * (docs/chat/83-chat-result-card-plan.md §2.4, §3).
 *
 * <p>Bean validation on {@link MessageCard} has already bounded every number and
 * length by the time {@link #validated} runs; what is left here is what an
 * annotation cannot say — which sub-object belongs to which kind, and that the
 * time is not in the future. It also returns a <em>normalised copy</em> (strings
 * trimmed), because what is stored is exactly what was validated, not whatever
 * the client sent.
 *
 * <p>Static on purpose: {@code ChatMapper} is a static mapper, and the card is
 * read back into a response from there. The mapper below is this class's own —
 * it has to produce the same ISO instants Boot's Jackson 3 mapper writes to
 * clients, so that what is stored and what is served agree.
 */
public final class MessageCards {

    private static final Logger log = LoggerFactory.getLogger(MessageCards.class);

    /** Clock skew between a phone and the server, not an invitation to schedule cards. */
    private static final Duration FUTURE_TOLERANCE = Duration.ofDays(1);

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
            // A card stored by a newer build and read by an older one must still read.
            .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);

    private MessageCards() {
    }

    /**
     * @return the card with its strings trimmed
     * @throws InvalidMessageCardException when the sub-objects do not match the kind
     */
    public static MessageCard validated(MessageCard card, Instant now) {
        if (card.kind() == null || card.occurredAt() == null) {
            throw new InvalidMessageCardException("A card needs a kind and a time");
        }
        if (card.occurredAt().isAfter(now.plus(FUTURE_TOLERANCE))) {
            throw new InvalidMessageCardException("A card cannot be from the future");
        }
        return switch (card.kind()) {
            case WORKOUT -> {
                if (card.workout() == null || card.pr() != null) {
                    throw new InvalidMessageCardException("A WORKOUT card carries a workout and nothing else");
                }
                MessageCard.Workout w = card.workout();
                yield new MessageCard(card.kind(), card.sessionId(), card.occurredAt(),
                        new MessageCard.Workout(w.workoutKind(), blankToNull(w.title()), w.durationSeconds(),
                                w.volumeKg(), w.exerciseCount(), w.distanceMeters(), w.recordCount()),
                        null);
            }
            case PR -> {
                if (card.pr() == null || card.workout() != null) {
                    throw new InvalidMessageCardException("A PR card carries a record and nothing else");
                }
                MessageCard.Pr p = card.pr();
                String exercise = blankToNull(p.exerciseName());
                if (exercise == null) {
                    throw new InvalidMessageCardException("A PR card needs the exercise's name");
                }
                yield new MessageCard(card.kind(), card.sessionId(), card.occurredAt(), null,
                        new MessageCard.Pr(exercise, p.prType(), p.value(), p.previousValue(), p.weightKg(),
                                p.reps()));
            }
        };
    }

    public static String toJson(MessageCard card) {
        try {
            return MAPPER.writeValueAsString(card);
        } catch (JsonProcessingException e) {
            // A validated record of strings, numbers and an Instant cannot fail to
            // serialise; if it ever does, that is a bug to see, not a message to drop.
            throw new IllegalStateException("Could not serialise a message card", e);
        }
    }

    /**
     * Reads a stored card back. A row that cannot be read — a hand-edited
     * value, a shape from the future — answers null and a warning rather than
     * throwing: one bad row must not make the whole thread unreadable.
     */
    public static MessageCard fromJson(String data) {
        if (data == null) {
            return null;
        }
        try {
            return MAPPER.readValue(data, MessageCard.class);
        } catch (JsonProcessingException e) {
            log.warn("Unreadable message card, serving the message without it: {}", e.getOriginalMessage());
            return null;
        }
    }

    private static String blankToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
