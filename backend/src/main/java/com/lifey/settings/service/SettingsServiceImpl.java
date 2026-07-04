package com.lifey.settings.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.settings.SettingsMapper;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.settings.dto.SettingsRequest;
import com.lifey.settings.dto.SettingsResponse;
import com.lifey.user.UserRepository;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional
public class SettingsServiceImpl implements SettingsService {

    private final UserSettingsRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    public SettingsResponse get() {
        return SettingsMapper.toResponse(getOrCreate());
    }

    @Override
    public SettingsResponse update(SettingsRequest request) {
        UserSettings settings = getOrCreate();
        SettingsMapper.applyRequest(settings, request);
        return SettingsMapper.toResponse(repository.save(settings));
    }

    @Override
    public SettingsResponse applyGoals(SuggestGoalsResponse goals) {
        UserSettings settings = getOrCreate();
        settings.setDailyCalorieGoal(goals.calories());
        settings.setDailyProteinGoal(goals.proteinGrams());
        settings.setDailyCarbsGoal(goals.carbsGrams());
        settings.setDailyFatGoal(goals.fatGrams());
        settings.setDailyWaterGoalLiters(goals.waterLiters());
        return SettingsMapper.toResponse(repository.save(settings));
    }

    /**
     * Settings rows aren't created at registration (the auth module doesn't know
     * about this feature), so the first read or write for a user creates the
     * default row instead.
     */
    private UserSettings getOrCreate() {
        Long userId = currentUserProvider.getUserId();
        return repository.findByUserId(userId).orElseGet(() -> {
            UserSettings settings = new UserSettings();
            settings.setUser(userRepository.getReferenceById(userId));
            return repository.save(settings);
        });
    }
}
