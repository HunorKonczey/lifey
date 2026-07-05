package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.mail.MailLanguage;
import com.lifey.mail.MailLanguageResolver;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.recipe.Recipe;
import com.lifey.nutrition.recipe.RecipeIngredient;
import com.lifey.nutrition.recipe.RecipeRepository;
import com.lifey.trainer.ContentAssignment;
import com.lifey.trainer.ContentAssignmentRepository;
import com.lifey.trainer.ContentType;
import com.lifey.trainer.dto.AssignmentListItemResponse;
import com.lifey.trainer.dto.AssignmentRequest;
import com.lifey.trainer.dto.AssignmentResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateExercise;
import com.lifey.workout.template.WorkoutTemplateRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

/**
 * Deep-copy content assignment (docs/personal_trainer/01-koncepcio-es-folyamatok.md,
 * "2. folyamat" and docs/personal_trainer/03-backend-terv.md). The whole
 * operation is one transaction: if copying a referenced exercise/food fails
 * partway through, nothing (not even the fact-log row) is left committed.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class ContentAssignmentServiceImpl implements ContentAssignmentService {

    private final ContentAssignmentRepository contentAssignmentRepository;
    private final WorkoutTemplateRepository workoutTemplateRepository;
    private final RecipeRepository recipeRepository;
    private final ExerciseRepository exerciseRepository;
    private final FoodRepository foodRepository;
    private final UserRepository userRepository;
    private final TrainerAccessService trainerAccessService;
    private final CurrentUserProvider currentUserProvider;
    private final MailLanguageResolver mailLanguageResolver;

    @Override
    public AssignmentResponse assign(AssignmentRequest request) {
        Long trainerId = currentUserProvider.getUserId();
        trainerAccessService.requireActiveClient(trainerId, request.clientId());

        boolean previouslyAssigned = contentAssignmentRepository.existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
                trainerId, request.clientId(), request.contentType(), request.sourceId());

        if (previouslyAssigned) {
            throw new DuplicateResourceException("This content has already been assigned to this client");
        }

        Long copiedId = switch (request.contentType()) {
            case TEMPLATE -> assignTemplate(trainerId, request.clientId(), request.sourceId());
            case RECIPE -> assignRecipe(trainerId, request.clientId(), request.sourceId());
        };

        ContentAssignment assignment = new ContentAssignment();
        assignment.setTrainer(userRepository.getReferenceById(trainerId));
        assignment.setClient(userRepository.getReferenceById(request.clientId()));
        assignment.setContentType(request.contentType());
        assignment.setSourceId(request.sourceId());
        assignment.setCopiedId(copiedId);
        assignment.setAssignedAt(Instant.now());
        ContentAssignment saved = contentAssignmentRepository.save(assignment);

        return toResponse(saved, previouslyAssigned);
    }

    @Override
    @Transactional(readOnly = true)
    public List<AssignmentListItemResponse> findForClient(Long clientId) {
        Long trainerId = currentUserProvider.getUserId();
        trainerAccessService.requireActiveClient(trainerId, clientId);

        return contentAssignmentRepository.findByTrainerIdAndClientIdOrderByAssignedAtDesc(trainerId, clientId).stream()
                .map(a -> new AssignmentListItemResponse(
                        a.getId(), a.getContentType(), a.getSourceId(), a.getCopiedId(), a.getAssignedAt()))
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<Long> findAssignedClientIds(ContentType contentType, Long sourceId) {
        Long trainerId = currentUserProvider.getUserId();
        return contentAssignmentRepository.findByTrainerIdAndContentTypeAndSourceId(trainerId, contentType, sourceId).stream()
                .map(a -> a.getClient().getId())
                .toList();
    }

    @Override
    public void unassign(Long assignmentId) {
        Long trainerId = currentUserProvider.getUserId();
        ContentAssignment assignment = contentAssignmentRepository.findByIdAndTrainerId(assignmentId, trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Assignment not found: " + assignmentId));

        Long clientId = assignment.getClient().getId();
        switch (assignment.getContentType()) {
            case TEMPLATE -> workoutTemplateRepository.findByIdAndUserId(assignment.getCopiedId(), clientId)
                    .ifPresent(t -> t.setDeletedAt(Instant.now()));
            case RECIPE -> recipeRepository.findByIdAndUserId(assignment.getCopiedId(), clientId)
                    .ifPresent(r -> r.setDeletedAt(Instant.now()));
        }

        contentAssignmentRepository.delete(assignment);
    }

    private Long assignTemplate(Long trainerId, Long clientId, Long templateId) {
        WorkoutTemplate source = workoutTemplateRepository.findByIdAndUserId(templateId, trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Workout template not found: " + templateId));

        User client = userRepository.getReferenceById(clientId);
        WorkoutTemplate copy = new WorkoutTemplate();
        copy.setUser(client);
        copy.setName(source.getName());
        copy.setOriginSourceId(source.getId());
        copy.setOriginTrainerId(trainerId);

        for (WorkoutTemplateExercise link : source.getExercises()) {
            Exercise exerciseCopy = resolveExerciseCopy(trainerId, clientId, client, link.getExercise());

            WorkoutTemplateExercise copyLink = new WorkoutTemplateExercise();
            copyLink.setWorkoutTemplate(copy);
            copyLink.setExercise(exerciseCopy);
            copyLink.setTargetSets(link.getTargetSets());
            copyLink.setSortOrder(link.getSortOrder());
            copy.getExercises().add(copyLink);
        }

        return workoutTemplateRepository.save(copy).getId();
    }

    private Long assignRecipe(Long trainerId, Long clientId, Long recipeId) {
        Recipe source = recipeRepository.findByIdAndUserId(recipeId, trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Recipe not found: " + recipeId));

        User client = userRepository.getReferenceById(clientId);
        Recipe copy = new Recipe();
        copy.setUser(client);
        copy.setName(source.getName());
        copy.setDescription(source.getDescription());
        copy.setServings(source.getServings());
        copy.setOriginSourceId(source.getId());
        copy.setOriginTrainerId(trainerId);

        for (RecipeIngredient ingredient : source.getIngredients()) {
            Food foodCopy = resolveFoodCopy(trainerId, clientId, client, ingredient.getFood());

            RecipeIngredient copyIngredient = new RecipeIngredient();
            copyIngredient.setRecipe(copy);
            copyIngredient.setFood(foodCopy);
            copyIngredient.setQuantityInGrams(ingredient.getQuantityInGrams());
            copy.getIngredients().add(copyIngredient);
        }

        return recipeRepository.save(copy).getId();
    }

    /**
     * Reuses the client's existing copy of this exact trainer exercise if one
     * already exists (from an earlier assignment), so re-assigning a template
     * that shares exercises with a previous one doesn't duplicate them.
     */
    private Exercise resolveExerciseCopy(Long trainerId, Long clientId, User client, Exercise source) {
        return exerciseRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
                        clientId, trainerId, source.getId())
                .orElseGet(() -> {
                    Exercise copy = new Exercise();
                    copy.setUser(client);
                    copy.setName(source.getName());
                    copy.setCategory(source.getCategory());
                    copy.setEquipment(source.getEquipment());
                    copy.setOriginSourceId(source.getId());
                    copy.setOriginTrainerId(trainerId);
                    return exerciseRepository.save(copy);
                });
    }

    private Food resolveFoodCopy(Long trainerId, Long clientId, User client, Food source) {
        return foodRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
                        clientId, trainerId, source.getId())
                .orElseGet(() -> createOrReuseFoodCopy(trainerId, clientId, client, source));
    }

    /**
     * The client may already own a visible food with this exact name (their
     * own entry, or a copy from a different trainer/recipe) — the
     * {@code foods_name_unique_idx} constraint forbids a second one. If its
     * macros match the trainer's food, reuse it as-is (same food, no need for
     * a copy). Otherwise create the copy under a disambiguated name so both
     * can coexist.
     */
    private Food createOrReuseFoodCopy(Long trainerId, Long clientId, User client, Food source) {
        Optional<Food> conflicting = source.isHidden()
                ? Optional.empty()
                : foodRepository.findByUserIdAndNameIgnoreCaseAndHiddenFalse(clientId, source.getName().trim());

        if (conflicting.isPresent() && macrosMatch(conflicting.get(), source)) {
            return conflicting.get();
        }

        Food copy = new Food();
        copy.setUser(client);
        copy.setName(conflicting.isPresent() ? disambiguatedName(source.getName(), client) : source.getName());
        copy.setCaloriesPer100g(source.getCaloriesPer100g());
        copy.setProteinPer100g(source.getProteinPer100g());
        copy.setCarbsPer100g(source.getCarbsPer100g());
        copy.setFatPer100g(source.getFatPer100g());
        copy.setHidden(source.isHidden());
        copy.setOriginSourceId(source.getId());
        copy.setOriginTrainerId(trainerId);
        return foodRepository.save(copy);
    }

    private boolean macrosMatch(Food a, Food b) {
        return Double.compare(a.getCaloriesPer100g(), b.getCaloriesPer100g()) == 0
                && Double.compare(a.getProteinPer100g(), b.getProteinPer100g()) == 0
                && Objects.equals(a.getCarbsPer100g(), b.getCarbsPer100g())
                && Objects.equals(a.getFatPer100g(), b.getFatPer100g());
    }

    private String disambiguatedName(String name, User client) {
        String suffix = mailLanguageResolver.resolve(client) == MailLanguage.HU ? "Edzőtől" : "From trainer";
        return name + " (" + suffix + ")";
    }

    private static AssignmentResponse toResponse(ContentAssignment a, boolean previouslyAssigned) {
        return new AssignmentResponse(
                a.getId(), a.getContentType(), a.getSourceId(), a.getCopiedId(), a.getAssignedAt(), previouslyAssigned);
    }
}
