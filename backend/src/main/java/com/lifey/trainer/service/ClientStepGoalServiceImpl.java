package com.lifey.trainer.service;

import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.settings.dto.SettingsResponse;
import com.lifey.settings.service.SettingsService;
import com.lifey.trainer.dto.ClientStepGoalRequest;
import com.lifey.trainer.dto.ClientStepGoalResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;
import java.util.Objects;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Transactional
public class ClientStepGoalServiceImpl implements ClientStepGoalService {

    private final TrainerAccessService trainerAccessService;
    private final SettingsService settingsService;
    private final UserSettingsRepository userSettingsRepository;
    private final PushService pushService;

    @Override
    public ClientStepGoalResponse updateStepGoal(Long trainerId, Long clientId, ClientStepGoalRequest request) {
        trainerAccessService.requireActiveClient(trainerId, clientId);
        Integer before = settingsService.forUser(clientId).dailyStepGoal();
        Integer after = settingsService.updateStepGoalForUser(clientId, request.dailyStepGoal()).dailyStepGoal();
        if (!Objects.equals(before, after)) {
            sendPush(clientId, after);
        }
        return new ClientStepGoalResponse(after);
    }

    private void sendPush(Long clientId, Integer goal) {
        Optional<UserSettings> settings = userSettingsRepository.findByUserId(clientId);
        if (!settings.map(UserSettings::isTrainerGoalsPushEnabled).orElse(true)) {
            return;
        }
        boolean hungarian = settings.map(s -> s.getLanguage() == LanguagePreference.HUNGARIAN).orElse(false);
        pushService.sendToUser(clientId, buildMessage(goal, hungarian));
    }

    private static PushMessage buildMessage(Integer goal, boolean hungarian) {
        String title = hungarian
                ? "Az edződ frissítette a lépéscélodat"
                : "Your trainer updated your step goal";
        String body = goal == null
                ? (hungarian ? "A lépéscél törölve" : "Step goal cleared")
                : (hungarian ? goal + " lépés naponta" : goal + " steps a day");
        return new PushMessage(title, body, Map.of("type", "step_goal"));
    }
}
