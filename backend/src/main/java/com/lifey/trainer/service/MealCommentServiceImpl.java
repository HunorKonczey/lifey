package com.lifey.trainer.service;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.meal.Meal;
import com.lifey.nutrition.meal.MealMapper;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.nutrition.meal.MealType;
import com.lifey.nutrition.meal.dto.MealResponse;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Transactional
public class MealCommentServiceImpl implements MealCommentService {

    private final TrainerAccessService trainerAccessService;
    private final MealRepository mealRepository;
    private final UserSettingsRepository userSettingsRepository;
    private final PushService pushService;

    @Override
    public MealResponse upsertComment(Long trainerId, Long clientId, Long mealId, String comment) {
        Meal meal = getOwnedMeal(trainerId, clientId, mealId);
        boolean isNewComment = meal.getTrainerComment() == null;
        meal.setTrainerComment(comment);
        meal.setTrainerCommentAt(Instant.now());
        meal.setTrainerCommentBy(trainerId);
        if (isNewComment) {
            sendCommentPush(meal);
        }
        return MealMapper.toResponse(meal);
    }

    @Override
    public MealResponse deleteComment(Long trainerId, Long clientId, Long mealId) {
        Meal meal = getOwnedMeal(trainerId, clientId, mealId);
        meal.setTrainerComment(null);
        meal.setTrainerCommentAt(null);
        meal.setTrainerCommentBy(null);
        return MealMapper.toResponse(meal);
    }

    private Meal getOwnedMeal(Long trainerId, Long clientId, Long mealId) {
        trainerAccessService.requireActiveClient(trainerId, clientId);
        return mealRepository.findByIdAndUserId(mealId, clientId)
                .filter(m -> m.getDeletedAt() == null)
                .orElseThrow(() -> new ResourceNotFoundException("Meal not found: " + mealId));
    }

    private void sendCommentPush(Meal meal) {
        Long clientId = meal.getUser().getId();
        Optional<UserSettings> settings = userSettingsRepository.findByUserId(clientId);
        // The one switch that already covers every comment a trainer writes (V56).
        if (!settings.map(UserSettings::isTrainerCommentPushEnabled).orElse(true)) {
            return;
        }
        boolean hungarian = settings.map(s -> s.getLanguage() == LanguagePreference.HUNGARIAN).orElse(false);
        pushService.sendToUser(clientId, buildMessage(meal, hungarian));
    }

    private static PushMessage buildMessage(Meal meal, boolean hungarian) {
        String title = hungarian ? "Új megjegyzés az edződtől" : "New comment from your trainer";
        String label = meal.getName() != null && !meal.getName().isBlank()
                ? meal.getName()
                : typeLabel(meal.getMealType(), hungarian);
        String body = label + ": " + SessionCommentServiceImpl.truncate(meal.getTrainerComment());
        Map<String, String> data = Map.of(
                "type", "meal_comment",
                "mealId", String.valueOf(meal.getId())
        );
        return new PushMessage(title, body, data);
    }

    private static String typeLabel(MealType type, boolean hungarian) {
        return switch (type) {
            case BREAKFAST -> hungarian ? "Reggeli" : "Breakfast";
            case LUNCH -> hungarian ? "Ebéd" : "Lunch";
            case DINNER -> hungarian ? "Vacsora" : "Dinner";
            case SNACK -> hungarian ? "Nasi" : "Snack";
        };
    }
}
