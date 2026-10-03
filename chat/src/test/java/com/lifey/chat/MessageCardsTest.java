package com.lifey.chat;

import com.lifey.chat.dto.MessageCard;
import com.lifey.chat.exception.InvalidMessageCardException;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** The cross-field rules and the storage format of a result card (docs/chat/83 §2.4, §3). */
class MessageCardsTest {

    private static final Instant NOW = Instant.parse("2026-10-03T08:00:00Z");
    private static final Instant WHEN = Instant.parse("2026-10-03T07:12:00Z");

    private static MessageCard.Workout workout() {
        return new MessageCard.Workout(MessageCard.WorkoutKind.CARDIO, "  Easy run  ", 1800, null, null, 5200.0, 0);
    }

    private static MessageCard.Pr pr() {
        return new MessageCard.Pr("  Bench press ", MessageCard.PrType.REPS_AT_WEIGHT, 8.0, 6.0, 80.0, 8);
    }

    @Test
    void aWorkoutCard_isTrimmedAndKeepsItsNumbers() {
        MessageCard card = MessageCards.validated(
                new MessageCard(MessageCard.Kind.WORKOUT, 481L, WHEN, workout(), null), NOW);

        assertThat(card.workout().title()).isEqualTo("Easy run");
        assertThat(card.workout().distanceMeters()).isEqualTo(5200.0);
        assertThat(card.workout().recordCount()).isZero();
        assertThat(card.pr()).isNull();
    }

    @Test
    void anUnnamedWorkout_isFine_aBlankTitleBecomesNull() {
        MessageCard.Workout blank = new MessageCard.Workout(
                MessageCard.WorkoutKind.STRENGTH, "   ", null, null, null, null, null);

        MessageCard card = MessageCards.validated(new MessageCard(MessageCard.Kind.WORKOUT, null, WHEN, blank, null), NOW);

        assertThat(card.workout().title()).isNull();
        assertThat(card.sessionId()).isNull();
    }

    @Test
    void aPrCard_isTrimmed() {
        MessageCard card = MessageCards.validated(new MessageCard(MessageCard.Kind.PR, null, WHEN, null, pr()), NOW);

        assertThat(card.pr().exerciseName()).isEqualTo("Bench press");
    }

    @Test
    void aPrCard_withABlankExerciseName_isRejected() {
        MessageCard.Pr blank = new MessageCard.Pr("   ", MessageCard.PrType.MAX_WEIGHT, 100.0, null, null, null);

        assertThatThrownBy(() -> MessageCards.validated(new MessageCard(MessageCard.Kind.PR, null, WHEN, null, blank), NOW))
                .isInstanceOf(InvalidMessageCardException.class);
    }

    @Test
    void theKindDecidesWhichSubObjectMustBeThere() {
        assertThatThrownBy(() -> MessageCards.validated(new MessageCard(MessageCard.Kind.WORKOUT, null, WHEN, null, pr()), NOW))
                .isInstanceOf(InvalidMessageCardException.class);
        assertThatThrownBy(() -> MessageCards.validated(new MessageCard(MessageCard.Kind.PR, null, WHEN, workout(), null), NOW))
                .isInstanceOf(InvalidMessageCardException.class);
        assertThatThrownBy(() -> MessageCards.validated(new MessageCard(MessageCard.Kind.PR, null, WHEN, workout(), pr()), NOW))
                .isInstanceOf(InvalidMessageCardException.class);
        assertThatThrownBy(() -> MessageCards.validated(new MessageCard(MessageCard.Kind.WORKOUT, null, WHEN, null, null), NOW))
                .isInstanceOf(InvalidMessageCardException.class);
    }

    @Test
    void aCardFromTheFuture_isRejected_butClockSkewIsTolerated() {
        assertThatThrownBy(() -> MessageCards.validated(
                new MessageCard(MessageCard.Kind.WORKOUT, null, NOW.plusSeconds(3 * 86_400), workout(), null), NOW))
                .isInstanceOf(InvalidMessageCardException.class);

        MessageCard skewed = MessageCards.validated(
                new MessageCard(MessageCard.Kind.WORKOUT, null, NOW.plusSeconds(600), workout(), null), NOW);
        assertThat(skewed.occurredAt()).isEqualTo(NOW.plusSeconds(600));
    }

    @Test
    void theStoredJson_roundTrips_andWritesInstantsAsIso() {
        MessageCard original = MessageCards.validated(
                new MessageCard(MessageCard.Kind.PR, 481L, WHEN, null, pr()), NOW);

        String json = MessageCards.toJson(original);

        // Not epoch numbers: stored and served must agree on the format.
        assertThat(json).contains("\"occurredAt\":\"2026-10-03T07:12:00Z\"");
        assertThat(MessageCards.fromJson(json)).isEqualTo(original);
    }

    @Test
    void aStoredCardFromANewerBuild_withAnExtraField_stillReads() {
        String json = "{\"kind\":\"PR\",\"sessionId\":null,\"occurredAt\":\"2026-10-03T07:12:00Z\","
                + "\"workout\":null,\"shiny\":true,"
                + "\"pr\":{\"exerciseName\":\"Squat\",\"prType\":\"MAX_WEIGHT\",\"value\":140.0,\"tempo\":\"3-1-1\"}}";

        MessageCard card = MessageCards.fromJson(json);

        assertThat(card).isNotNull();
        assertThat(card.pr().exerciseName()).isEqualTo("Squat");
    }

    @Test
    void anUnreadableRow_answersNull_soOneBadRowCannotBreakTheThread() {
        assertThat(MessageCards.fromJson("{not json")).isNull();
        assertThat(MessageCards.fromJson(null)).isNull();
    }
}
