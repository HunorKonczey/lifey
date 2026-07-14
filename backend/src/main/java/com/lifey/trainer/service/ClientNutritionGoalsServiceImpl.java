package com.lifey.trainer.service;

import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.settings.dto.SettingsResponse;
import com.lifey.settings.service.SettingsService;
import com.lifey.trainer.dto.ClientNutritionGoalsRequest;
import com.lifey.trainer.dto.ClientNutritionGoalsResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Transactional
public class ClientNutritionGoalsServiceImpl implements ClientNutritionGoalsService {

    private final TrainerAccessService trainerAccessService;
    private final SettingsService settingsService;
    private final UserSettingsRepository userSettingsRepository;
    private final PushService pushService;

    @Override
    public ClientNutritionGoalsResponse updateGoals(Long trainerId, Long clientId, ClientNutritionGoalsRequest request) {
        trainerAccessService.requireActiveClient(trainerId, clientId);
        SettingsResponse before = settingsService.forUser(clientId);
        SettingsResponse updated = settingsService.updateNutritionGoalsForUser(
                clientId, request.dailyCalorieGoal(), request.dailyProteinGoal(),
                request.dailyCarbsGoal(), request.dailyFatGoal());
        if (changed(before, updated)) {
            sendGoalsPush(clientId, updated);
        }
        return new ClientNutritionGoalsResponse(
                updated.dailyCalorieGoal(), updated.dailyProteinGoal(),
                updated.dailyCarbsGoal(), updated.dailyFatGoal());
    }

    private static boolean changed(SettingsResponse before, SettingsResponse after) {
        return !Objects.equals(before.dailyCalorieGoal(), after.dailyCalorieGoal())
                || !Objects.equals(before.dailyProteinGoal(), after.dailyProteinGoal())
                || !Objects.equals(before.dailyCarbsGoal(), after.dailyCarbsGoal())
                || !Objects.equals(before.dailyFatGoal(), after.dailyFatGoal());
    }

    private void sendGoalsPush(Long clientId, SettingsResponse updated) {
        Optional<UserSettings> settings = userSettingsRepository.findByUserId(clientId);
        if (!settings.map(UserSettings::isTrainerGoalsPushEnabled).orElse(true)) {
            return;
        }
        boolean hungarian = settings.map(s -> s.getLanguage() == LanguagePreference.HUNGARIAN).orElse(false);
        pushService.sendToUser(clientId, buildMessage(updated, hungarian));
    }

    private static PushMessage buildMessage(SettingsResponse updated, boolean hungarian) {
        String title = hungarian
                ? "Az edződ frissítette a táplálkozási céljaidat"
                : "Your trainer updated your nutrition goals";
        String body = summarize(updated, hungarian);
        Map<String, String> data = Map.of("type", "nutrition_goals");
        return new PushMessage(title, body, data);
    }

    private static String summarize(SettingsResponse s, boolean hungarian) {
        List<String> parts = new ArrayList<>();
        if (s.dailyCalorieGoal() != null) {
            parts.add(s.dailyCalorieGoal() + " kcal");
        }
        if (s.dailyProteinGoal() != null) {
            parts.add((hungarian ? "fehérje " : "protein ") + s.dailyProteinGoal() + " g");
        }
        if (s.dailyCarbsGoal() != null) {
            parts.add((hungarian ? "szénhidrát " : "carbs ") + s.dailyCarbsGoal() + " g");
        }
        if (s.dailyFatGoal() != null) {
            parts.add((hungarian ? "zsír " : "fat ") + s.dailyFatGoal() + " g");
        }
        if (parts.isEmpty()) {
            return hungarian ? "A célok törölve" : "Goals cleared";
        }
        return String.join(" · ", parts);
    }
}
