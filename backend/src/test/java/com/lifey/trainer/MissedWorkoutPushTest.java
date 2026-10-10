package com.lifey.trainer;

import com.lifey.push.service.PushMessage;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/** The wording and folding of the trainer's "missed workout" push (docs/85-trainer-push-plan.md). */
class MissedWorkoutPushTest {

    // 2026-10-05 is a Monday.
    private static final LocalDate MONDAY = LocalDate.of(2026, 10, 5);

    @Test
    void oneMissedWorkout_namesTheClientTheWorkoutAndTheDay() {
        PushMessage message = MissedWorkoutPush.build(List.of(miss(1L, "Anna Kovacs", MONDAY, "Push day")), false);

        assertThat(message.title()).isEqualTo("Missed workout");
        assertThat(message.body()).isEqualTo("Anna Kovacs missed Push day (Monday)");
        assertThat(message.data()).containsEntry("type", "client_missed_workout").containsEntry("clientId", "1");
    }

    @Test
    void oneMissedWorkout_inHungarian() {
        PushMessage message = MissedWorkoutPush.build(List.of(miss(1L, "Kovács Anna", MONDAY, "Push day")), true);

        assertThat(message.title()).isEqualTo("Kihagyott edzés");
        assertThat(message.body()).isEqualTo("Kovács Anna kihagyta: Push day (hétfő)");
    }

    @Test
    void aWorkoutWithoutAName_isStillAnnounced() {
        PushMessage message = MissedWorkoutPush.build(List.of(miss(1L, "Anna", MONDAY, null)), false);

        assertThat(message.body()).isEqualTo("Anna missed a workout (Monday)");
    }

    @Test
    void severalMissesOfOneClient_areCountedAndStillOpenThatClient() {
        PushMessage message = MissedWorkoutPush.build(
                List.of(miss(1L, "Anna", MONDAY, "Push"), miss(1L, "Anna", MONDAY.plusDays(2), "Pull")), false);

        assertThat(message.body()).isEqualTo("Anna missed 2 workouts");
        assertThat(message.data()).containsEntry("clientId", "1");
    }

    @Test
    void severalClients_areFoldedIntoOneMessageWithNoSingleClientToOpen() {
        PushMessage message = MissedWorkoutPush.build(List.of(
                miss(1L, "Anna", MONDAY, "Push"),
                miss(2L, "Bela", MONDAY, "Push"),
                miss(3L, "Cili", MONDAY, "Push"),
                miss(3L, "Cili", MONDAY.plusDays(1), "Pull")), false);

        assertThat(message.body()).isEqualTo("3 clients missed a workout: Anna, Bela, +1");
        assertThat(message.data()).containsEntry("type", "client_missed_workout").doesNotContainKey("clientId");
    }

    @Test
    void twoClients_listBothNames_inHungarian() {
        PushMessage message = MissedWorkoutPush.build(
                List.of(miss(1L, "Anna", MONDAY, "Push"), miss(2L, "Bela", MONDAY, "Push")), true);

        assertThat(message.body()).isEqualTo("2 kliens kihagyott egy edzést: Anna, Bela");
    }

    private static MissedOccurrence miss(Long clientId, String name, LocalDate day, String workout) {
        return new MissedOccurrence(clientId * 100 + day.getDayOfMonth(), day, workout, 9L, 0, clientId, name + "@example.com", name, null);
    }
}
