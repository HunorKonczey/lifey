package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.mail.MailLanguage;
import com.lifey.mail.MailLanguageResolver;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.recipe.Recipe;
import com.lifey.nutrition.recipe.RecipeImage;
import com.lifey.nutrition.recipe.RecipeImageRepository;
import com.lifey.nutrition.recipe.RecipeIngredient;
import com.lifey.nutrition.recipe.RecipeRepository;
import com.lifey.trainer.ContentAssignmentRepository;
import com.lifey.trainer.ContentType;
import com.lifey.trainer.dto.AssignmentListItemResponse;
import com.lifey.trainer.dto.AssignmentRequest;
import com.lifey.trainer.dto.BulkAssignmentResponse;
import com.lifey.trainer.entity.ContentAssignment;
import com.lifey.trainer.entity.TrainerClient;
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

import java.time.Instant;
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
    private static final Long OTHER_CLIENT_ID = 3L;

    @Mock
    ContentAssignmentRepository contentAssignmentRepository;

    @Mock
    WorkoutTemplateRepository workoutTemplateRepository;

    @Mock
    RecipeRepository recipeRepository;

    @Mock
    RecipeImageRepository recipeImageRepository;

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

    @Mock
    MailLanguageResolver mailLanguageResolver;

    @InjectMocks
    ContentAssignmentServiceImpl service;

    @BeforeEach
    void setUp() {
        // Not every test reaches the deep-copy step that resolves these references,
        // and the propagate* tests take trainerId as a parameter instead of going
        // through CurrentUserProvider at all.
        lenient().when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        lenient().when(userRepository.getReferenceById(TRAINER_ID)).thenReturn(user(TRAINER_ID));
        lenient().when(userRepository.getReferenceById(CLIENT_ID)).thenReturn(user(CLIENT_ID));
        lenient().when(userRepository.getReferenceById(OTHER_CLIENT_ID)).thenReturn(user(OTHER_CLIENT_ID));
        // Recipe tests below don't set up a photo — copyRecipeImage's source lookup
        // just needs to resolve to "no image" so it can no-op.
        lenient().when(recipeImageRepository.findByRecipeId(any())).thenReturn(Optional.empty());
    }

    @Test
    void assign_throwsWhenNotAnActiveClient() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID))
                .thenThrow(new NotYourClientException("nope"));

        assertThatThrownBy(() -> service.assign(new AssignmentRequest(List.of(CLIENT_ID), ContentType.TEMPLATE, 7L)))
                .isInstanceOf(NotYourClientException.class);
        verify(contentAssignmentRepository, never()).save(any());
    }

    @Test
    void assign_template_throwsWhenTemplateNotOwnedByTrainer() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.assign(new AssignmentRequest(List.of(CLIENT_ID), ContentType.TEMPLATE, 7L)))
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

        BulkAssignmentResponse result = service.assign(new AssignmentRequest(List.of(CLIENT_ID), ContentType.TEMPLATE, 7L));

        assertThat(result.assignments()).singleElement().satisfies(item -> {
            assertThat(item.clientId()).isEqualTo(CLIENT_ID);
            assertThat(item.copiedId()).isEqualTo(88L);
        });
        assertThat(result.skippedClientIds()).isEmpty();

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

        service.assign(new AssignmentRequest(List.of(CLIENT_ID), ContentType.TEMPLATE, 7L));

        verify(exerciseRepository, never()).save(any());
        ArgumentCaptor<WorkoutTemplate> captor = ArgumentCaptor.forClass(WorkoutTemplate.class);
        verify(workoutTemplateRepository).save(captor.capture());
        assertThat(captor.getValue().getExercises()).singleElement()
                .satisfies(l -> assertThat(l.getExercise()).isSameAs(existingCopy));
    }

    @Test
    void resolveClientCopy_reusesLiveClientCopy_whenOneExists() {
        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        WorkoutTemplate existingCopy = new WorkoutTemplate();
        existingCopy.setId(55L);
        when(workoutTemplateRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
                CLIENT_ID, TRAINER_ID, 7L)).thenReturn(Optional.of(existingCopy));

        WorkoutTemplate result = service.resolveClientCopy(TRAINER_ID, CLIENT_ID, source);

        assertThat(result).isSameAs(existingCopy);
        verify(contentAssignmentRepository, never()).save(any());
    }

    @Test
    void resolveClientCopy_deepCopies_whenNoLiveCopyExists() {
        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day");
        when(workoutTemplateRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
                CLIENT_ID, TRAINER_ID, 7L)).thenReturn(Optional.empty());
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));
        when(workoutTemplateRepository.save(any(WorkoutTemplate.class))).thenAnswer(inv -> {
            WorkoutTemplate t = inv.getArgument(0);
            t.setId(88L);
            return t;
        });
        when(contentAssignmentRepository.existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
                TRAINER_ID, CLIENT_ID, ContentType.TEMPLATE, 7L)).thenReturn(false);
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));
        when(workoutTemplateRepository.getReferenceById(88L)).thenAnswer(_ -> {
            WorkoutTemplate t = new WorkoutTemplate();
            t.setId(88L);
            return t;
        });

        WorkoutTemplate result = service.resolveClientCopy(TRAINER_ID, CLIENT_ID, source);

        assertThat(result.getId()).isEqualTo(88L);
        verify(contentAssignmentRepository).save(any(ContentAssignment.class));
    }

    @Test
    void resolveClientCopy_throwsWhenFactRowExistsButClientDeletedTheirCopy() {
        // The client deleted their copy after the assignment: the live-copy
        // lookup misses but the fact row remains — silently re-copying would
        // resurrect the deleted content, so this must keep throwing (unlike
        // the bulk endpoint's skip semantics).
        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        when(workoutTemplateRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
                CLIENT_ID, TRAINER_ID, 7L)).thenReturn(Optional.empty());
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(contentAssignmentRepository.existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
                TRAINER_ID, CLIENT_ID, ContentType.TEMPLATE, 7L)).thenReturn(true);

        assertThatThrownBy(() -> service.resolveClientCopy(TRAINER_ID, CLIENT_ID, source))
                .isInstanceOf(DuplicateResourceException.class);
        verify(contentAssignmentRepository, never()).save(any());
    }

    @Test
    void propagateTemplateUpdate_updatesExistingCopyNameAndExercisesAndBumpsUpdatedAt() {
        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day v2");
        Exercise sourceExercise = new Exercise();
        sourceExercise.setId(30L);
        WorkoutTemplateExercise link = new WorkoutTemplateExercise();
        link.setExercise(sourceExercise);
        link.setTargetSets(5);
        link.setSortOrder(0);
        source.getExercises().add(link);
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));

        ContentAssignment assignment = new ContentAssignment();
        assignment.setClient(user(CLIENT_ID));
        assignment.setCopiedId(88L);
        when(contentAssignmentRepository.findByTrainerIdAndContentTypeAndSourceId(TRAINER_ID, ContentType.TEMPLATE, 7L))
                .thenReturn(List.of(assignment));

        WorkoutTemplate copy = new WorkoutTemplate();
        copy.setId(88L);
        copy.setName("Push day");
        copy.setUpdatedAt(Instant.parse("2026-06-18T08:00:00Z"));
        when(workoutTemplateRepository.findByIdAndUserId(88L, CLIENT_ID)).thenReturn(Optional.of(copy));
        when(exerciseRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(CLIENT_ID, TRAINER_ID, 30L))
                .thenReturn(Optional.empty());
        when(exerciseRepository.save(any(Exercise.class))).thenAnswer(inv -> {
            Exercise e = inv.getArgument(0);
            e.setId(99L);
            return e;
        });

        service.propagateTemplateUpdate(TRAINER_ID, 7L);

        assertThat(copy.getName()).isEqualTo("Push day v2");
        assertThat(copy.getExercises()).singleElement().satisfies(l -> {
            assertThat(l.getExercise().getId()).isEqualTo(99L);
            assertThat(l.getTargetSets()).isEqualTo(5);
        });
        assertThat(copy.getUpdatedAt()).isAfter(Instant.parse("2026-06-18T08:00:00Z"));
    }

    @Test
    void propagateTemplateUpdate_skipsAssignmentWhenClientCopyMissing() {
        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day");
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));

        ContentAssignment assignment = new ContentAssignment();
        assignment.setClient(user(CLIENT_ID));
        assignment.setCopiedId(88L);
        when(contentAssignmentRepository.findByTrainerIdAndContentTypeAndSourceId(TRAINER_ID, ContentType.TEMPLATE, 7L))
                .thenReturn(List.of(assignment));
        when(workoutTemplateRepository.findByIdAndUserId(88L, CLIENT_ID)).thenReturn(Optional.empty());

        service.propagateTemplateUpdate(TRAINER_ID, 7L);

        verify(exerciseRepository, never()).save(any());
    }

    @Test
    void propagateTemplateUpdate_reusesAlreadyCopiedExercise() {
        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day");
        Exercise sourceExercise = new Exercise();
        sourceExercise.setId(30L);
        WorkoutTemplateExercise link = new WorkoutTemplateExercise();
        link.setExercise(sourceExercise);
        source.getExercises().add(link);
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));

        ContentAssignment assignment = new ContentAssignment();
        assignment.setClient(user(CLIENT_ID));
        assignment.setCopiedId(88L);
        when(contentAssignmentRepository.findByTrainerIdAndContentTypeAndSourceId(TRAINER_ID, ContentType.TEMPLATE, 7L))
                .thenReturn(List.of(assignment));
        WorkoutTemplate copy = new WorkoutTemplate();
        copy.setId(88L);
        when(workoutTemplateRepository.findByIdAndUserId(88L, CLIENT_ID)).thenReturn(Optional.of(copy));

        Exercise existingCopy = new Exercise();
        existingCopy.setId(55L);
        when(exerciseRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(CLIENT_ID, TRAINER_ID, 30L))
                .thenReturn(Optional.of(existingCopy));

        service.propagateTemplateUpdate(TRAINER_ID, 7L);

        verify(exerciseRepository, never()).save(any());
        assertThat(copy.getExercises()).singleElement()
                .satisfies(l -> assertThat(l.getExercise()).isSameAs(existingCopy));
    }

    @Test
    void propagateTemplateUpdate_shrinksCopyExercisesWhenSourceExerciseRemoved() {
        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day");
        // source now has zero exercises — trainer removed the only one
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));

        ContentAssignment assignment = new ContentAssignment();
        assignment.setClient(user(CLIENT_ID));
        assignment.setCopiedId(88L);
        when(contentAssignmentRepository.findByTrainerIdAndContentTypeAndSourceId(TRAINER_ID, ContentType.TEMPLATE, 7L))
                .thenReturn(List.of(assignment));

        WorkoutTemplate copy = new WorkoutTemplate();
        copy.setId(88L);
        WorkoutTemplateExercise staleLink = new WorkoutTemplateExercise();
        Exercise staleExercise = new Exercise();
        staleExercise.setId(99L);
        staleLink.setExercise(staleExercise);
        copy.getExercises().add(staleLink);
        when(workoutTemplateRepository.findByIdAndUserId(88L, CLIENT_ID)).thenReturn(Optional.of(copy));

        service.propagateTemplateUpdate(TRAINER_ID, 7L);

        assertThat(copy.getExercises()).isEmpty();
    }

    @Test
    void propagateTemplateUpdate_throwsWhenSourceNotOwnedByTrainer() {
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.propagateTemplateUpdate(TRAINER_ID, 7L))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(contentAssignmentRepository, never()).findByTrainerIdAndContentTypeAndSourceId(any(), any(), any());
    }

    @Test
    void propagateRecipeUpdate_updatesExistingCopyFieldsAndIngredientsAndBumpsUpdatedAt() {
        Recipe source = new Recipe();
        source.setId(12L);
        source.setName("Protein shake v2");
        source.setDescription("blend it longer");
        source.setServings(3);
        Food sourceFood = new Food();
        sourceFood.setId(40L);
        sourceFood.setName("Whey");
        sourceFood.setCaloriesPer100g(400);
        sourceFood.setProteinPer100g(80);
        RecipeIngredient ingredient = new RecipeIngredient();
        ingredient.setFood(sourceFood);
        ingredient.setQuantityInGrams(40);
        source.getIngredients().add(ingredient);
        when(recipeRepository.findByIdAndUserId(12L, TRAINER_ID)).thenReturn(Optional.of(source));

        ContentAssignment assignment = new ContentAssignment();
        assignment.setClient(user(CLIENT_ID));
        assignment.setCopiedId(66L);
        when(contentAssignmentRepository.findByTrainerIdAndContentTypeAndSourceId(TRAINER_ID, ContentType.RECIPE, 12L))
                .thenReturn(List.of(assignment));

        Recipe copy = new Recipe();
        copy.setId(66L);
        copy.setName("Protein shake");
        copy.setUpdatedAt(Instant.parse("2026-06-18T08:00:00Z"));
        when(recipeRepository.findByIdAndUserId(66L, CLIENT_ID)).thenReturn(Optional.of(copy));
        when(foodRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(CLIENT_ID, TRAINER_ID, 40L))
                .thenReturn(Optional.empty());
        when(foodRepository.save(any(Food.class))).thenAnswer(inv -> {
            Food f = inv.getArgument(0);
            f.setId(77L);
            return f;
        });

        service.propagateRecipeUpdate(TRAINER_ID, 12L);

        assertThat(copy.getName()).isEqualTo("Protein shake v2");
        assertThat(copy.getDescription()).isEqualTo("blend it longer");
        assertThat(copy.getServings()).isEqualTo(3);
        assertThat(copy.getIngredients()).singleElement()
                .satisfies(i -> assertThat(i.getFood().getId()).isEqualTo(77L));
        assertThat(copy.getUpdatedAt()).isAfter(Instant.parse("2026-06-18T08:00:00Z"));
    }

    @Test
    void propagateRecipeUpdate_skipsAssignmentWhenClientCopyMissing() {
        Recipe source = new Recipe();
        source.setId(12L);
        source.setName("Protein shake");
        when(recipeRepository.findByIdAndUserId(12L, TRAINER_ID)).thenReturn(Optional.of(source));

        ContentAssignment assignment = new ContentAssignment();
        assignment.setClient(user(CLIENT_ID));
        assignment.setCopiedId(66L);
        when(contentAssignmentRepository.findByTrainerIdAndContentTypeAndSourceId(TRAINER_ID, ContentType.RECIPE, 12L))
                .thenReturn(List.of(assignment));
        when(recipeRepository.findByIdAndUserId(66L, CLIENT_ID)).thenReturn(Optional.empty());

        service.propagateRecipeUpdate(TRAINER_ID, 12L);

        verify(foodRepository, never()).save(any());
    }

    @Test
    void propagateRecipeUpdate_throwsWhenSourceNotOwnedByTrainer() {
        when(recipeRepository.findByIdAndUserId(12L, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.propagateRecipeUpdate(TRAINER_ID, 12L))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(contentAssignmentRepository, never()).findByTrainerIdAndContentTypeAndSourceId(any(), any(), any());
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

        BulkAssignmentResponse result = service.assign(new AssignmentRequest(List.of(CLIENT_ID), ContentType.RECIPE, 12L));

        assertThat(result.assignments()).singleElement()
                .satisfies(item -> assertThat(item.copiedId()).isEqualTo(66L));

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
    void assign_recipe_reusesClientsExistingFoodWhenNameAndMacrosMatch() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());

        Recipe source = new Recipe();
        source.setId(12L);
        source.setName("Protein shake");
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

        Food clientsExistingFood = new Food();
        clientsExistingFood.setId(88L);
        clientsExistingFood.setName("Whey");
        clientsExistingFood.setCaloriesPer100g(400);
        clientsExistingFood.setProteinPer100g(80);

        when(recipeRepository.findByIdAndUserId(12L, TRAINER_ID)).thenReturn(Optional.of(source));
        when(foodRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(CLIENT_ID, TRAINER_ID, 40L))
                .thenReturn(Optional.empty());
        when(foodRepository.findByUserIdAndNameIgnoreCaseAndHiddenFalse(CLIENT_ID, "Whey"))
                .thenReturn(Optional.of(clientsExistingFood));
        when(recipeRepository.save(any(Recipe.class))).thenAnswer(inv -> inv.getArgument(0));
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));

        service.assign(new AssignmentRequest(List.of(CLIENT_ID), ContentType.RECIPE, 12L));

        verify(foodRepository, never()).save(any());
        ArgumentCaptor<Recipe> recipeCaptor = ArgumentCaptor.forClass(Recipe.class);
        verify(recipeRepository).save(recipeCaptor.capture());
        assertThat(recipeCaptor.getValue().getIngredients()).singleElement()
                .satisfies(i -> assertThat(i.getFood()).isSameAs(clientsExistingFood));
    }

    @Test
    void assign_recipe_disambiguatesFoodNameWhenClientsExistingFoodHasDifferentMacros() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(mailLanguageResolver.resolve(any(User.class))).thenReturn(MailLanguage.HU);

        Recipe source = new Recipe();
        source.setId(12L);
        source.setName("Protein shake");
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

        Food clientsExistingFood = new Food();
        clientsExistingFood.setId(88L);
        clientsExistingFood.setName("Whey");
        clientsExistingFood.setCaloriesPer100g(250);
        clientsExistingFood.setProteinPer100g(20);

        when(recipeRepository.findByIdAndUserId(12L, TRAINER_ID)).thenReturn(Optional.of(source));
        when(foodRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(CLIENT_ID, TRAINER_ID, 40L))
                .thenReturn(Optional.empty());
        when(foodRepository.findByUserIdAndNameIgnoreCaseAndHiddenFalse(CLIENT_ID, "Whey"))
                .thenReturn(Optional.of(clientsExistingFood));
        when(foodRepository.save(any(Food.class))).thenAnswer(inv -> {
            Food f = inv.getArgument(0);
            f.setId(77L);
            return f;
        });
        when(recipeRepository.save(any(Recipe.class))).thenAnswer(inv -> inv.getArgument(0));
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));

        service.assign(new AssignmentRequest(List.of(CLIENT_ID), ContentType.RECIPE, 12L));

        ArgumentCaptor<Food> foodCaptor = ArgumentCaptor.forClass(Food.class);
        verify(foodRepository).save(foodCaptor.capture());
        assertThat(foodCaptor.getValue().getName()).isEqualTo("Whey (Edzőtől)");
    }

    @Test
    void assign_allClientsAlreadyAssigned_returnsAllSkippedWithoutCopying() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        Recipe source = new Recipe();
        source.setId(12L);
        source.setName("Protein shake");
        when(recipeRepository.findByIdAndUserId(12L, TRAINER_ID)).thenReturn(Optional.of(source));
        when(contentAssignmentRepository.existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
                TRAINER_ID, CLIENT_ID, ContentType.RECIPE, 12L)).thenReturn(true);

        BulkAssignmentResponse result = service.assign(new AssignmentRequest(List.of(CLIENT_ID), ContentType.RECIPE, 12L));

        assertThat(result.assignments()).isEmpty();
        assertThat(result.skippedClientIds()).containsExactly(CLIENT_ID);
        verify(recipeRepository, never()).save(any());
        verify(contentAssignmentRepository, never()).save(any());
    }

    @Test
    void assign_recipe_throwsWhenRecipeNotOwnedByTrainer() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(recipeRepository.findByIdAndUserId(12L, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.assign(new AssignmentRequest(List.of(CLIENT_ID), ContentType.RECIPE, 12L)))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(contentAssignmentRepository, never()).save(any());
    }

    @Test
    void assign_skipsAlreadyAssignedClient_andCopiesForTheRestOfTheBatch() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(trainerAccessService.requireActiveClient(TRAINER_ID, OTHER_CLIENT_ID)).thenReturn(new TrainerClient());

        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day");
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));
        when(contentAssignmentRepository.existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
                TRAINER_ID, CLIENT_ID, ContentType.TEMPLATE, 7L)).thenReturn(true);
        when(contentAssignmentRepository.existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
                TRAINER_ID, OTHER_CLIENT_ID, ContentType.TEMPLATE, 7L)).thenReturn(false);
        when(workoutTemplateRepository.save(any(WorkoutTemplate.class))).thenAnswer(inv -> {
            WorkoutTemplate t = inv.getArgument(0);
            t.setId(88L);
            return t;
        });
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));

        BulkAssignmentResponse result = service.assign(
                new AssignmentRequest(List.of(CLIENT_ID, OTHER_CLIENT_ID), ContentType.TEMPLATE, 7L));

        assertThat(result.skippedClientIds()).containsExactly(CLIENT_ID);
        assertThat(result.assignments()).singleElement().satisfies(item -> {
            assertThat(item.clientId()).isEqualTo(OTHER_CLIENT_ID);
            assertThat(item.copiedId()).isEqualTo(88L);
        });
        verify(workoutTemplateRepository, times(1)).save(any());
        verify(contentAssignmentRepository, times(1)).save(any());
    }

    @Test
    void assign_bulk_copiesForEveryClient_reusingEachClientsOwnExerciseCopies() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(trainerAccessService.requireActiveClient(TRAINER_ID, OTHER_CLIENT_ID)).thenReturn(new TrainerClient());

        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day");
        Exercise sourceExercise = new Exercise();
        sourceExercise.setId(30L);
        sourceExercise.setName("Bench Press");
        WorkoutTemplateExercise link = new WorkoutTemplateExercise();
        link.setExercise(sourceExercise);
        source.getExercises().add(link);
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));

        // CLIENT_ID already owns a copy of the exercise (earlier assignment); OTHER_CLIENT_ID doesn't.
        Exercise existingCopy = new Exercise();
        existingCopy.setId(55L);
        when(exerciseRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(CLIENT_ID, TRAINER_ID, 30L))
                .thenReturn(Optional.of(existingCopy));
        when(exerciseRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(OTHER_CLIENT_ID, TRAINER_ID, 30L))
                .thenReturn(Optional.empty());
        when(exerciseRepository.save(any(Exercise.class))).thenAnswer(inv -> {
            Exercise e = inv.getArgument(0);
            e.setId(99L);
            return e;
        });
        long[] nextTemplateId = {88L};
        when(workoutTemplateRepository.save(any(WorkoutTemplate.class))).thenAnswer(inv -> {
            WorkoutTemplate t = inv.getArgument(0);
            t.setId(nextTemplateId[0]++);
            return t;
        });
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));

        BulkAssignmentResponse result = service.assign(
                new AssignmentRequest(List.of(CLIENT_ID, OTHER_CLIENT_ID), ContentType.TEMPLATE, 7L));

        assertThat(result.assignments()).hasSize(2);
        assertThat(result.assignments()).extracting(BulkAssignmentResponse.BulkAssignmentItem::clientId)
                .containsExactly(CLIENT_ID, OTHER_CLIENT_ID);
        assertThat(result.skippedClientIds()).isEmpty();
        // Only OTHER_CLIENT_ID needed a fresh exercise copy.
        verify(exerciseRepository, times(1)).save(any());
        verify(workoutTemplateRepository, times(2)).save(any());
        verify(contentAssignmentRepository, times(2)).save(any());
        // The source is loaded once for the whole batch.
        verify(workoutTemplateRepository, times(1)).findByIdAndUserId(7L, TRAINER_ID);
    }

    @Test
    void assign_dedupesRepeatedClientIds() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());

        WorkoutTemplate source = new WorkoutTemplate();
        source.setId(7L);
        source.setName("Push day");
        when(workoutTemplateRepository.findByIdAndUserId(7L, TRAINER_ID)).thenReturn(Optional.of(source));
        when(workoutTemplateRepository.save(any(WorkoutTemplate.class))).thenAnswer(inv -> {
            WorkoutTemplate t = inv.getArgument(0);
            t.setId(88L);
            return t;
        });
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));

        BulkAssignmentResponse result = service.assign(
                new AssignmentRequest(List.of(CLIENT_ID, CLIENT_ID), ContentType.TEMPLATE, 7L));

        assertThat(result.assignments()).hasSize(1);
        verify(workoutTemplateRepository, times(1)).save(any());
        verify(contentAssignmentRepository, times(1)).save(any());
    }

    @Test
    void assign_revokedClientInBatch_failsBeforeAnyCopying() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(trainerAccessService.requireActiveClient(TRAINER_ID, OTHER_CLIENT_ID))
                .thenThrow(new NotYourClientException("nope"));

        assertThatThrownBy(() -> service.assign(
                new AssignmentRequest(List.of(CLIENT_ID, OTHER_CLIENT_ID), ContentType.TEMPLATE, 7L)))
                .isInstanceOf(NotYourClientException.class);

        verify(workoutTemplateRepository, never()).findByIdAndUserId(any(), any());
        verify(workoutTemplateRepository, never()).save(any());
        verify(contentAssignmentRepository, never()).save(any());
    }

    @Test
    void assign_bulk_copiesRecipeImageForEveryClient() {
        when(trainerAccessService.requireActiveClient(TRAINER_ID, CLIENT_ID)).thenReturn(new TrainerClient());
        when(trainerAccessService.requireActiveClient(TRAINER_ID, OTHER_CLIENT_ID)).thenReturn(new TrainerClient());

        Recipe source = new Recipe();
        source.setId(12L);
        source.setName("Protein shake");
        source.setServings(2);
        when(recipeRepository.findByIdAndUserId(12L, TRAINER_ID)).thenReturn(Optional.of(source));
        long[] nextRecipeId = {66L};
        when(recipeRepository.save(any(Recipe.class))).thenAnswer(inv -> {
            Recipe r = inv.getArgument(0);
            r.setId(nextRecipeId[0]++);
            return r;
        });
        when(contentAssignmentRepository.save(any(ContentAssignment.class))).thenAnswer(inv -> inv.getArgument(0));

        RecipeImage sourceImage = new RecipeImage();
        sourceImage.setRecipe(source);
        when(recipeImageRepository.findByRecipeId(12L)).thenReturn(Optional.of(sourceImage));
        // Fresh copies (66, 67) have no image row yet — the lenient any() stub in setUp covers them.

        service.assign(new AssignmentRequest(List.of(CLIENT_ID, OTHER_CLIENT_ID), ContentType.RECIPE, 12L));

        verify(recipeImageRepository, times(2)).save(any(RecipeImage.class));
    }

    @Test
    void findAssignedClientIds_returnsClientsAlreadyAssignedThisContent() {
        ContentAssignment a = new ContentAssignment();
        a.setClient(user(CLIENT_ID));
        when(contentAssignmentRepository.findByTrainerIdAndContentTypeAndSourceId(TRAINER_ID, ContentType.RECIPE, 12L))
                .thenReturn(List.of(a));

        List<Long> result = service.findAssignedClientIds(ContentType.RECIPE, 12L);

        assertThat(result).containsExactly(CLIENT_ID);
    }

    @Test
    void unassign_softDeletesTheClientsCopyAndRemovesTheAssignment() {
        ContentAssignment assignment = new ContentAssignment();
        assignment.setId(5L);
        assignment.setClient(user(CLIENT_ID));
        assignment.setContentType(ContentType.RECIPE);
        assignment.setCopiedId(66L);
        when(contentAssignmentRepository.findByIdAndTrainerId(5L, TRAINER_ID)).thenReturn(Optional.of(assignment));

        Recipe copy = new Recipe();
        copy.setId(66L);
        when(recipeRepository.findByIdAndUserId(66L, CLIENT_ID)).thenReturn(Optional.of(copy));

        service.unassign(5L);

        assertThat(copy.getDeletedAt()).isNotNull();
        verify(contentAssignmentRepository).delete(assignment);
    }

    @Test
    void unassign_throwsWhenAssignmentNotOwnedByTrainer() {
        when(contentAssignmentRepository.findByIdAndTrainerId(5L, TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.unassign(5L)).isInstanceOf(ResourceNotFoundException.class);
        verify(contentAssignmentRepository, never()).delete(any());
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
