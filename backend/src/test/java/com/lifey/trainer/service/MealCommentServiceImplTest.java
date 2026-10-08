package com.lifey.trainer.service;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.meal.Meal;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.nutrition.meal.MealType;
import com.lifey.nutrition.meal.dto.MealResponse;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.user.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MealCommentServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;
    private static final Long MEAL_ID = 3L;

    @Mock
    TrainerAccessService trainerAccessService;

    @Mock
    MealRepository mealRepository;

    @Mock
    UserSettingsRepository userSettingsRepository;

    @Mock
    PushService pushService;

    @InjectMocks
    MealCommentServiceImpl service;

    private Meal meal;

    @BeforeEach
    void setUp() {
        User client = new User();
        client.setId(CLIENT_ID);
        meal = new Meal();
        meal.setId(MEAL_ID);
        meal.setUser(client);
        meal.setMealType(MealType.LUNCH);
        meal.setDateTime(Instant.parse("2026-06-01T12:00:00Z"));
    }

    private void mealIsFound() {
        when(mealRepository.findByIdAndUserId(MEAL_ID, CLIENT_ID)).thenReturn(Optional.of(meal));
    }

    private static UserSettings clientSettings(LanguagePreference language, boolean commentPush) {
        UserSettings s = new UserSettings();
        s.setLanguage(language);
        s.setTrainerCommentPushEnabled(commentPush);
        return s;
    }

    @Test
    void upsertComment_stampsTheCommentItsTimeAndItsAuthor() {
        mealIsFound();
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        MealResponse result = service.upsertComment(TRAINER_ID, CLIENT_ID, MEAL_ID, "Add some greens");

        verify(trainerAccessService).requireActiveClient(TRAINER_ID, CLIENT_ID);
        assertThat(meal.getTrainerComment()).isEqualTo("Add some greens");
        assertThat(meal.getTrainerCommentBy()).isEqualTo(TRAINER_ID);
        assertThat(meal.getTrainerCommentAt()).isNotNull();
        assertThat(result.trainerComment()).isEqualTo("Add some greens");
        assertThat(result.trainerCommentAt()).isEqualTo(meal.getTrainerCommentAt());
    }

    @Test
    void upsertComment_theFirstCommentPushesTheClientWithTheMealAndTheStart() {
        mealIsFound();
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        service.upsertComment(TRAINER_ID, CLIENT_ID, MEAL_ID, "Add some greens");

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("New comment from your trainer");
        assertThat(captor.getValue().body()).isEqualTo("Lunch: Add some greens");
        assertThat(captor.getValue().data()).containsEntry("type", "meal_comment").containsEntry("mealId", "3");
    }

    @Test
    void upsertComment_aNamedMealIsCalledByItsNameAndHungarianIsSpoken() {
        meal.setName("Csirkés tál");
        mealIsFound();
        when(userSettingsRepository.findByUserId(CLIENT_ID))
                .thenReturn(Optional.of(clientSettings(LanguagePreference.HUNGARIAN, true)));

        service.upsertComment(TRAINER_ID, CLIENT_ID, MEAL_ID, "Több zöldség");

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("Új megjegyzés az edződtől");
        assertThat(captor.getValue().body()).isEqualTo("Csirkés tál: Több zöldség");
    }

    @Test
    void upsertComment_editingAnExistingCommentDoesNotPushAgain() {
        meal.setTrainerComment("first");
        mealIsFound();

        service.upsertComment(TRAINER_ID, CLIENT_ID, MEAL_ID, "second");

        assertThat(meal.getTrainerComment()).isEqualTo("second");
        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void upsertComment_aClientWhoTurnedCommentPushesOffIsNotNotified() {
        mealIsFound();
        when(userSettingsRepository.findByUserId(CLIENT_ID))
                .thenReturn(Optional.of(clientSettings(LanguagePreference.SYSTEM, false)));

        service.upsertComment(TRAINER_ID, CLIENT_ID, MEAL_ID, "Add some greens");

        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void deleteComment_clearsTheCommentItsTimeAndItsAuthor() {
        meal.setTrainerComment("old");
        meal.setTrainerCommentAt(Instant.now());
        meal.setTrainerCommentBy(TRAINER_ID);
        mealIsFound();

        MealResponse result = service.deleteComment(TRAINER_ID, CLIENT_ID, MEAL_ID);

        assertThat(meal.getTrainerComment()).isNull();
        assertThat(meal.getTrainerCommentAt()).isNull();
        assertThat(meal.getTrainerCommentBy()).isNull();
        assertThat(result.trainerComment()).isNull();
    }

    @Test
    void aDeletedOrForeignMealIsNotFoundAndNotCommentable() {
        meal.setDeletedAt(Instant.now());
        mealIsFound();

        assertThatThrownBy(() -> service.upsertComment(TRAINER_ID, CLIENT_ID, MEAL_ID, "x"))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.deleteComment(TRAINER_ID, CLIENT_ID, 99L))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(pushService, never()).sendToUser(any(), any());
    }

    @Test
    void notYourClientPropagatesAndTouchesNothing() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID))
                .thenThrow(new NotYourClientException("nope"));

        assertThatThrownBy(() -> service.upsertComment(TRAINER_ID, CLIENT_ID, MEAL_ID, "x"))
                .isInstanceOf(NotYourClientException.class);

        verify(mealRepository, never()).findByIdAndUserId(any(), any());
        verify(pushService, never()).sendToUser(any(), any());
    }
}
