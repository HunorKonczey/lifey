package com.lifey.settings.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.settings.GoalsSource;
import com.lifey.settings.NutritionGoalsAttribution;
import com.lifey.settings.SettingsMapper;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.settings.dto.NutritionGoalsSourceResponse;
import com.lifey.settings.dto.SettingsRequest;
import com.lifey.settings.dto.SettingsResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

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
        Integer[] before = nutritionGoals(settings);
        SettingsMapper.applyRequest(settings, request);
        // The client re-sends its whole settings object on every change, so attribution moves only when a goal really did.
        stampIfNutritionGoalsChanged(settings, before, currentUserProvider.getUserId());
        return SettingsMapper.toResponse(repository.save(settings));
    }

    @Override
    public SettingsResponse applyGoals(SuggestGoalsResponse goals) {
        UserSettings settings = getOrCreate();
        Integer[] before = nutritionGoals(settings);
        settings.setDailyCalorieGoal(goals.calories());
        settings.setDailyProteinGoal(goals.proteinGrams());
        settings.setDailyCarbsGoal(goals.carbsGrams());
        settings.setDailyFatGoal(goals.fatGrams());
        settings.setDailyWaterGoalLiters(goals.waterLiters());
        stampIfNutritionGoalsChanged(settings, before, currentUserProvider.getUserId());
        return SettingsMapper.toResponse(repository.save(settings));
    }

    @Override
    public SettingsResponse forUser(Long userId) {
        return SettingsMapper.toResponse(getOrCreate(userId));
    }

    @Override
    public SettingsResponse updateNutritionGoalsForUser(
            Long userId, Long actorId, Integer dailyCalorieGoal, Integer dailyProteinGoal,
            Integer dailyCarbsGoal, Integer dailyFatGoal) {
        UserSettings settings = getOrCreate(userId);
        Integer[] before = nutritionGoals(settings);
        settings.setDailyCalorieGoal(dailyCalorieGoal);
        settings.setDailyProteinGoal(dailyProteinGoal);
        settings.setDailyCarbsGoal(dailyCarbsGoal);
        settings.setDailyFatGoal(dailyFatGoal);
        stampIfNutritionGoalsChanged(settings, before, actorId);
        return SettingsMapper.toResponse(repository.save(settings));
    }

    @Override
    public SettingsResponse updateStepGoalForUser(Long userId, Integer dailyStepGoal) {
        UserSettings settings = getOrCreate(userId);
        settings.setDailyStepGoal(dailyStepGoal);
        return SettingsMapper.toResponse(repository.save(settings));
    }

    @Override
    @Transactional(readOnly = true)
    public NutritionGoalsAttribution nutritionGoalsAttribution(Long userId) {
        return repository.findByUserId(userId)
                .map(s -> NutritionGoalsAttribution.of(userId, s.getNutritionGoalsSetAt(), s.getNutritionGoalsSetBy()))
                .orElseGet(NutritionGoalsAttribution::unknown);
    }

    @Override
    @Transactional(readOnly = true)
    public NutritionGoalsSourceResponse nutritionGoalsSource() {
        Long userId = currentUserProvider.getUserId();
        NutritionGoalsAttribution attribution = nutritionGoalsAttribution(userId);
        String name = null;
        if (attribution.source() == GoalsSource.TRAINER && attribution.setByUserId() != null) {
            name = userRepository.findById(attribution.setByUserId()).map(SettingsServiceImpl::displayName).orElse(null);
        }
        return new NutritionGoalsSourceResponse(attribution.source(), attribution.setAt(), name);
    }

    private static Integer[] nutritionGoals(UserSettings s) {
        return new Integer[]{s.getDailyCalorieGoal(), s.getDailyProteinGoal(), s.getDailyCarbsGoal(), s.getDailyFatGoal()};
    }

    /** Records who changed the goals, but only if one of the four values differs from what it was before. */
    private static void stampIfNutritionGoalsChanged(UserSettings s, Integer[] before, Long actorId) {
        Integer[] after = nutritionGoals(s);
        if (NutritionGoalsAttribution.goalsDiffer(before[0], before[1], before[2], before[3],
                after[0], after[1], after[2], after[3])) {
            s.setNutritionGoalsSetBy(actorId);
            s.setNutritionGoalsSetAt(Instant.now());
        }
    }

    private static String displayName(User user) {
        String full = ((user.getFirstName() == null ? "" : user.getFirstName()) + " "
                + (user.getLastName() == null ? "" : user.getLastName())).trim();
        return full.isEmpty() ? user.getEmail() : full;
    }

    @Override
    public boolean isWeeklyReportEmailEnabled() {
        return getOrCreate().isWeeklyReportEmailEnabled();
    }

    @Override
    public boolean setWeeklyReportEmailEnabled(boolean enabled) {
        UserSettings settings = getOrCreate();
        settings.setWeeklyReportEmailEnabled(enabled);
        return repository.save(settings).isWeeklyReportEmailEnabled();
    }

    /**
     * Settings rows aren't created at registration (the auth module doesn't know
     * about this feature), so the first read or write for a user creates the
     * default row instead.
     */
    private UserSettings getOrCreate() {
        return getOrCreate(currentUserProvider.getUserId());
    }

    private UserSettings getOrCreate(Long userId) {
        return repository.findByUserId(userId).orElseGet(() -> {
            UserSettings settings = new UserSettings();
            settings.setUser(userRepository.getReferenceById(userId));
            return repository.save(settings);
        });
    }
}
