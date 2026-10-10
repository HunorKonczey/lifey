package com.lifey.trainer;

import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.weight.WeightLoggedEvent;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.time.Clock;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/**
 * Tells a client's trainers that the client logged this week's weigh-in (docs/85-trainer-push-plan.md): the first entry of
 * the client's Monday-Sunday week, dated in the current week - not a late sync of an old one, not a second entry. Runs after
 * the commit, so an entry that was rolled back is never announced, and never lets an exception out: a failed push must not
 * turn a saved weigh-in into an error for the client.
 */
@Component
@RequiredArgsConstructor
class ClientWeighInPushListener {

    static final String TYPE = "client_weigh_in";

    private static final Logger log = LoggerFactory.getLogger(ClientWeighInPushListener.class);

    private final UserRepository userRepository;
    private final WeightEntryRepository weightEntryRepository;
    private final TrainerClientRepository trainerClientRepository;
    private final UserSettingsRepository userSettingsRepository;
    private final PushService pushService;
    private final Clock clock;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onWeightLogged(WeightLoggedEvent event) {
        try {
            notifyTrainers(event);
        } catch (RuntimeException e) {
            log.error("Could not notify the trainers about the weigh-in of user {}", event.userId(), e);
        }
    }

    private void notifyTrainers(WeightLoggedEvent event) {
        User client = userRepository.findById(event.userId()).orElse(null);
        if (client == null) {
            return;
        }
        ZoneOffset offset = ZoneOffset.ofTotalSeconds(client.getUtcOffsetMinutes() * 60);
        LocalDate clientToday = OffsetDateTime.ofInstant(clock.instant(), offset).toLocalDate();
        LocalDate weekStart = clientToday.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        LocalDate weekEnd = weekStart.plusDays(6);
        if (event.date().isBefore(weekStart) || event.date().isAfter(weekEnd)) {
            return;
        }
        if (weightEntryRepository.countByUserIdAndDeletedAtIsNullAndDateBetween(event.userId(), weekStart, weekEnd) != 1) {
            return;
        }

        String who = displayName(client);
        for (Long trainerId : trainerClientRepository.findTrainerIdsByClientIdAndStatus(event.userId(), TrainerClientStatus.ACTIVE)) {
            Optional<UserSettings> settings = userSettingsRepository.findByUserId(trainerId);
            if (!settings.map(UserSettings::isClientWeighInPushEnabled).orElse(true)) {
                continue;
            }
            boolean hungarian = settings.map(s -> s.getLanguage() == LanguagePreference.HUNGARIAN).orElse(false);
            pushService.sendToUser(trainerId, buildMessage(who, event, hungarian));
        }
    }

    static PushMessage buildMessage(String who, WeightLoggedEvent event, boolean hungarian) {
        String kg = String.format(hungarian ? Locale.forLanguageTag("hu") : Locale.ENGLISH, "%.1f kg", event.weight());
        String title = hungarian ? "Heti mérés" : "Weekly weigh-in";
        String body = hungarian ? who + " leadta a heti mérést: " + kg : who + " logged this week's weigh-in: " + kg;
        return new PushMessage(title, body, Map.of("type", TYPE, "clientId", String.valueOf(event.userId())));
    }

    private static String displayName(User user) {
        String first = user.getFirstName() == null ? "" : user.getFirstName().trim();
        String last = user.getLastName() == null ? "" : user.getLastName().trim();
        String full = (first + " " + last).trim();
        return full.isEmpty() ? user.getEmail() : full;
    }
}
