package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.recipe.Recipe;
import com.lifey.nutrition.recipe.RecipeIngredient;
import com.lifey.nutrition.recipe.RecipeRepository;
import com.lifey.trainer.ContentAssignment;
import com.lifey.trainer.ContentAssignmentRepository;
import com.lifey.trainer.ContentType;
import com.lifey.trainer.TrainerClient;
import com.lifey.trainer.dto.AssignmentListItemResponse;
import com.lifey.trainer.dto.AssignmentRequest;
import com.lifey.trainer.dto.AssignmentResponse;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Equipment;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.exercise.MuscleGroup;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateExercise;
import com.lifey.workout.template.WorkoutTemplateRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ContentAssignmentServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;

    @Mock
    ContentAssignmentRepository contentAssignmentRepository;

    @Mock
    WorkoutTemplateRepository workoutTemplateRepository;

    @Mock
    RecipeRepository recipeRepository;

    @Mock
    ExerciseRepository exerciseRepository;

    @Mock
    FoodRepository foodRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    TrainerAccessService trainerAccessService;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    ContentAssignmentServiceImpl service;

    @BeforeEach
    void setUp() {
        when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        // Not every test reaches the deep-copy step that resolves these references.
        lenient().when(userRepository.getReferenceById(TRAINER_ID)).thenReturn(user(TRAINER_ID));
        lenient().when(userRepository.getReferenceById(CLIENT_ID)).thenReturn(user(CLIENT_ID));
    }

    @Test
    void assign_throwsWhenNotAnActiveClient() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID))
                .thenThrow(new NotYourClientException("nope"));

        assertThatThrownBy(() -> service.assign(new AssignmentRequest(CLIENT_ID, ContentType.TEMPLATE, 7L)))
                .isInstanceOf(NotYourClientException.class);
        verify(contentAssignmentRepository, never()).save(any());
    }

    @Test
    void assign_template_throwsWhenTemplateNotOwnedByTrainer() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.assign(new AssignmentRequest(CLIENT_ID, ContentType.TEMPLATE, 7L)))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(contentAssignmentRepository, never()).save(any());
    }

    @Test
    void assign_template_deepCopiesTemplateAndItsExercises() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());

        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day");
        Exercise sourceExercise = new Exercise();
        sourceExercise.setId(30L);
        sourceExercise.setName("Bench Press");
        sourceExercise.setCategory(MuscleGroup.CHEST);
        sourceExercise.setEquipment(Equipment.BARBELL);
        WorkoutTemplateExercise link = new WorkoutTemplateExercise();
        link.setExercise(sourceExercise);
        link.setTargetSets(3);
        link.setSortOrder(0);
        source.getExercises().add(link);

        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));
        when(exerciseRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(CLIENT_ID, TRAINER_ID, 30L))
                .thenReturn(Optional.empty());
        when(exerciseRepository.save(any(Exercise.class))).thenAnswer(inv -> {
            Exercise e = inv.getArgument(0);
            e.setId(99L);
            return e;
        });
        when(workoutTemplateRepository.save(any(WorkoutTemplate.class))).thenAnswer(inv -> {
            WorkoutTemplate t = inv.getArgument(0);
            t.setId(88L);
            return t;
        });
        when(contentAssignmentRepository.existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
                TRAINER_ID, CLIENT_ID, ContentType.TEMPLATE, 7L)).thenReturn(false);
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));

        AssignmentResponse result = service.assign(new AssignmentRequest(CLIENT_ID, ContentType.TEMPLATE, 7L));

        assertThat(result.copiedId()).isEqualTo(88L);
        assertThat(result.sourceId()).isEqualTo(7L);
        assertThat(result.previouslyAssigned()).isFalse();

        ArgumentCaptor<WorkoutTemplate> templateCaptor = ArgumentCaptor.forClass(WorkoutTemplate.class);
        verify(workoutTemplateRepository).save(templateCaptor.capture());
        WorkoutTemplate savedTemplate = templateCaptor.getValue();
        assertThat(savedTemplate.getOriginSourceId()).isEqualTo(7L);
        assertThat(savedTemplate.getOriginTrainerId()).isEqualTo(TRAINER_ID);
        assertThat(savedTemplate.getExercises()).singleElement().satisfies(l -> {
            assertThat(l.getExercise().getId()).isEqualTo(99L);
            assertThat(l.getTargetSets()).isEqualTo(3);
        });

        ArgumentCaptor<Exercise> exerciseCaptor = ArgumentCaptor.forClass(Exercise.class);
        verify(exerciseRepository).save(exerciseCaptor.capture());
        assertThat(exerciseCaptor.getValue().getOriginSourceId()).isEqualTo(30L);
        assertThat(exerciseCaptor.getValue().getOriginTrainerId()).isEqualTo(TRAINER_ID);

        ArgumentCaptor<ContentAssignment> assignmentCaptor = ArgumentCaptor.forClass(ContentAssignment.class);
        verify(contentAssignmentRepository).save(assignmentCaptor.capture());
        assertThat(assignmentCaptor.getValue().getCopiedId()).isEqualTo(88L);
    }

    @Test
    void assign_template_reusesExistingClientCopyOfASharedExercise() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());

        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day");
        Exercise sourceExercise = new Exercise();
        sourceExercise.setId(30L);
        sourceExercise.setName("Bench Press");
        WorkoutTemplateExercise link = new WorkoutTemplateExercise();
        link.setExercise(sourceExercise);
        source.getExercises().add(link);

        Exercise existingCopy = new Exercise();
        existingCopy.setId(55L);

        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));
        when(exerciseRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(CLIENT_ID, TRAINER_ID, 30L))
                .thenReturn(Optional.of(existingCopy));
        when(workoutTemplateRepository.save(any(WorkoutTemplate.class))).thenAnswer(inv -> inv.getArgument(0));
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));

        service.assign(new AssignmentRequest(CLIENT_ID, ContentType.TEMPLATE, 7L));

        verify(exerciseRepository, never()).save(any());
        ArgumentCaptor<WorkoutTemplate> captor = ArgumentCaptor.forClass(WorkoutTemplate.class);
        verify(workoutTemplateRepository).save(captor.capture());
        assertThat(captor.getValue().getExercises()).singleElement()
                .satisfies(l -> assertThat(l.getExercise()).isSameAs(existingCopy));
    }

    @Test
    void assign_recipe_deepCopiesRecipeAndItsIngredients() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());

        Recipe source = new Recipe();
        source.setId(12L);
        source.setName("Protein shake");
        source.setDescription("blend it");
        source.setServings(2);
        Food sourceFood = new Food();
        sourceFood.setId(40L);
        sourceFood.setName("Whey");
        sourceFood.setCaloriesPer100g(400);
        sourceFood.setProteinPer100g(80);
        RecipeIngredient ingredient = new RecipeIngredient();
        ingredient.setFood(sourceFood);
        ingredient.setQuantityInGrams(30);
        source.getIngredients().add(ingredient);

        when(recipeRepository.findByIdAndUserId(12L, TRAINER_ID)).thenReturn(Optional.of(source));
        when(foodRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(CLIENT_ID, TRAINER_ID, 40L))
                .thenReturn(Optional.empty());
        when(foodRepository.save(any(Food.class))).thenAnswer(inv -> {
            Food f = inv.getArgument(0);
            f.setId(77L);
            return f;
        });
        when(recipeRepository.save(any(Recipe.class))).thenAnswer(inv -> {
            Recipe r = inv.getArgument(0);
            r.setId(66L);
            return r;
        });
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));

        AssignmentResponse result = service.assign(new AssignmentRequest(CLIENT_ID, ContentType.RECIPE, 12L));

        assertThat(result.copiedId()).isEqualTo(66L);

        ArgumentCaptor<Recipe> recipeCaptor = ArgumentCaptor.forClass(Recipe.class);
        verify(recipeRepository).save(recipeCaptor.capture());
        assertThat(recipeCaptor.getValue().getOriginSourceId()).isEqualTo(12L);
        assertThat(recipeCaptor.getValue().getIngredients()).singleElement()
                .satisfies(i -> assertThat(i.getFood().getId()).isEqualTo(77L));

        ArgumentCaptor<Food> foodCaptor = ArgumentCaptor.forClass(Food.class);
        verify(foodRepository).save(foodCaptor.capture());
        assertThat(foodCaptor.getValue().getOriginSourceId()).isEqualTo(40L);
    }

    @Test
    void assign_recipe_throwsWhenRecipeNotOwnedByTrainer() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(recipeRepository.findByIdAndUserId(12L, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.assign(new AssignmentRequest(CLIENT_ID, ContentType.RECIPE, 12L)))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(contentAssignmentRepository, never()).save(any());
    }

    @Test
    void assign_flagsPreviouslyAssignedWhenAlreadyAssignedBefore() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day");
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));
        when(workoutTemplateRepository.save(any(WorkoutTemplate.class))).thenAnswer(inv -> inv.getArgument(0));
        when(contentAssignmentRepository.existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
                TRAINER_ID, CLIENT_ID, ContentType.TEMPLATE, 7L)).thenReturn(true);
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));

        AssignmentResponse result = service.assign(new AssignmentRequest(CLIENT_ID, ContentType.TEMPLATE, 7L));

        assertThat(result.previouslyAssigned()).isTrue();
    }

    @Test
    void findForClient_guardsWithRequireActiveClientAndMapsAssignments() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        ContentAssignment a = new ContentAssignment();
        a.setId(1L);
        a.setContentType(ContentType.RECIPE);
        a.setSourceId(12L);
        a.setCopiedId(66L);
        when(contentAssignmentRepository.findByTrainerIdAndClientIdOrderByAssignedAtDesc(TRAINER_ID, CLIENT_ID))
                .thenReturn(List.of(a));

        List<AssignmentListItemResponse> result = service.findForClient(CLIENT_ID);

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.sourceId()).isEqualTo(12L);
            assertThat(r.copiedId()).isEqualTo(66L);
        });
    }

    @Test
    void findForClient_throwsWhenNotAnActiveClient() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID))
                .thenThrow(new NotYourClientException("nope"));

        assertThatThrownBy(() -> service.findForClient(CLIENT_ID)).isInstanceOf(NotYourClientException.class);
    }

    private static User user(Long id) {
        User u = new User();
        u.setId(id);
        return u;
    }
}
