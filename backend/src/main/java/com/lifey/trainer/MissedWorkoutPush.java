package com.lifey.trainer;

import com.lifey.push.service.PushMessage;

import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * The text of the trainer's "a client missed a workout" push (docs/85-trainer-push-plan.md): one message per trainer per
 * tick, so a bad Monday is one notification and not one per client. Pure, so the wording and the folding are tested without
 * a clock or a database.
 */
final class MissedWorkoutPush {

    static final String TYPE = "client_missed_workout";

    /** Names listed before "+N" in the folded message. */
    private static final int NAMES_SHOWN = 2;

    private MissedWorkoutPush() {
    }

    /** {@code occurrences} must be one trainer's, non-empty. */
    static PushMessage build(List<MissedOccurrence> occurrences, boolean hungarian) {
        Map<Long, List<MissedOccurrence>> byClient = new LinkedHashMap<>();
        for (MissedOccurrence occurrence : occurrences) {
            byClient.computeIfAbsent(occurrence.clientId(), id -> new ArrayList<>()).add(occurrence);
        }
        String title = hungarian ? "Kihagyott edzés" : "Missed workout";

        if (byClient.size() > 1) {
            List<String> names = byClient.values().stream().map(list -> list.getFirst().clientDisplayName()).toList();
            return new PushMessage(title, foldedBody(names, hungarian), Map.of("type", TYPE));
        }

        List<MissedOccurrence> own = byClient.values().iterator().next();
        MissedOccurrence first = own.getFirst();
        String who = first.clientDisplayName();
        String body;
        if (own.size() > 1) {
            body = hungarian ? who + " " + own.size() + " edzést hagyott ki" : who + " missed " + own.size() + " workouts";
        } else {
            Locale locale = hungarian ? Locale.forLanguageTag("hu") : Locale.ENGLISH;
            String day = first.scheduledFor().getDayOfWeek().getDisplayName(TextStyle.FULL, locale);
            String workout = first.workoutName() == null || first.workoutName().isBlank()
                    ? (hungarian ? "az edzést" : "a workout")
                    : first.workoutName().strip();
            body = hungarian ? who + " kihagyta: " + workout + " (" + day + ")" : who + " missed " + workout + " (" + day + ")";
        }
        return new PushMessage(title, body, Map.of("type", TYPE, "clientId", String.valueOf(first.clientId())));
    }

    private static String foldedBody(List<String> names, boolean hungarian) {
        String shown = String.join(", ", names.subList(0, Math.min(NAMES_SHOWN, names.size())));
        int more = names.size() - NAMES_SHOWN;
        String list = more > 0 ? shown + ", +" + more : shown;
        return hungarian
                ? names.size() + " kliens kihagyott egy edzést: " + list
                : names.size() + " clients missed a workout: " + list;
    }
}
