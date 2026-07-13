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
import java.util.ArrayList;
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
    private final RecipeImageRepository recipeImageRepository;
    private final ExerciseRepository exerciseRepository;
    private final FoodRepository foodRepository;
    private final UserRepository userRepository;
    private final TrainerAccessService trainerAccessService;
    private final CurrentUserProvider currentUserProvider;
    private final MailLanguageResolver mailLanguageResolver;

    @Override
    public BulkAssignmentResponse assign(AssignmentRequest request) {
        Long trainerId = currentUserProvider.getUserId();
        List<Long> clientIds = request.clientIds().stream().distinct().toList();

        // Guard the whole batch before any copying: one revoked client fails
        // the request with zero writes rather than a half-assigned batch
        // (belt and suspenders — the transaction would roll back anyway).
        clientIds.forEach(clientId -> trainerAccessService.requireActiveClient(trainerId, clientId));

        WorkoutTemplate sourceTemplate = request.contentType() == ContentType.TEMPLATE
                ? requireOwnedTemplate(trainerId, request.sourceId()) : null;
        Recipe sourceRecipe = request.contentType() == ContentType.RECIPE
                ? requireOwnedRecipe(trainerId, request.sourceId()) : null;

        List<BulkAssignmentResponse.BulkAssignmentItem> assignments = new ArrayList<>();
        List<Long> skippedClientIds = new ArrayList<>();
        for (Long clientId : clientIds) {
            // A duplicate is a skip here, not an error: the drawer locks
            // already-assigned rows, so one can only appear through a race or
            // a double submit — idempotent skip makes retries safe.
            if (contentAssignmentRepository.existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
                    trainerId, clientId, request.contentType(), request.sourceId())) {
                skippedClientIds.add(clientId);
                continue;
            }
            Long copiedId = switch (request.contentType()) {
                case TEMPLATE -> copyTemplateForClient(trainerId, clientId, sourceTemplate);
                case RECIPE -> copyRecipeForClient(trainerId, clientId, sourceRecipe);
            };
            ContentAssignment saved = saveFactRow(trainerId, clientId, request.contentType(), request.sourceId(), copiedId);
            assignments.add(new BulkAssignmentResponse.BulkAssignmentItem(
                    clientId, saved.getId(), saved.getCopiedId(), saved.getAssignedAt()));
        }
        return new BulkAssignmentResponse(assignments, skippedClientIds);
    }

    @Override
    public WorkoutTemplate resolveClientCopy(Long trainerId, Long clientId, WorkoutTemplate sourceTemplate) {
        return workoutTemplateRepository.findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
                        clientId, trainerId, sourceTemplate.getId())
                .orElseGet(() -> {
                    Long copiedId = assignOne(trainerId, clientId, ContentType.TEMPLATE, sourceTemplate.getId()).getCopiedId();
                    return workoutTemplateRepository.getReferenceById(copiedId);
                });
    }

    /**
     * Single-client assignment for the implicit paths ({@link #resolveClientCopy},
     * i.e. schedules and program assignments). Unlike the bulk endpoint's skip
     * semantics, an existing fact row here throws: reaching this with a fact
     * row but no live copy means the client deleted their copy, and silently
     * re-copying would resurrect it behind their back.
     */
    private ContentAssignment assignOne(Long trainerId, Long clientId, ContentType contentType, Long sourceId) {
        trainerAccessService.requireActiveClient(trainerId, clientId);

        if (contentAssignmentRepository.existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
                trainerId, clientId, contentType, sourceId)) {
            throw new DuplicateResourceException("This content has already been assigned to this client");
        }

        Long copiedId = switch (contentType) {
            case TEMPLATE -> copyTemplateForClient(trainerId, clientId, requireOwnedTemplate(trainerId, sourceId));
            case RECIPE -> copyRecipeForClient(trainerId, clientId, requireOwnedRecipe(trainerId, sourceId));
        };
        return saveFactRow(trainerId, clientId, contentType, sourceId, copiedId);
    }

    private ContentAssignment saveFactRow(Long trainerId, Long clientId, ContentType contentType, Long sourceId, Long copiedId) {
        ContentAssignment assignment = new ContentAssignment();
        assignment.setTrainer(userRepository.getReferenceById(trainerId));
        assignment.setClient(userRepository.getReferenceById(clientId));
        assignment.setContentType(contentType);
        assignment.setSourceId(sourceId);
        assignment.setCopiedId(copiedId);
        assignment.setAssignedAt(Instant.now());
        return contentAssignmentRepository.save(assignment);
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

    private WorkoutTemplate requireOwnedTemplate(Long trainerId, Long templateId) {
        return workoutTemplateRepository.findByIdAndUserId(templateId, trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Workout template not found: " + templateId));
    }

    private Recipe requireOwnedRecipe(Long trainerId, Long recipeId) {
        return recipeRepository.findByIdAndUserId(recipeId, trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Recipe not found: " + recipeId));
    }

    private Long copyTemplateForClient(Long trainerId, Long clientId, WorkoutTemplate source) {
        User client = userRepository.getReferenceById(clientId);
        WorkoutTemplate copy = new WorkoutTemplate();
        copy.setUser(client);
        copy.setOriginSourceId(source.getId());
        copy.setOriginTrainerId(trainerId);
        copyTemplateFields(copy, source, trainerId, clientId, client);

        return workoutTemplateRepository.save(copy).getId();
    }

    private Long copyRecipeForClient(Long trainerId, Long clientId, Recipe source) {
        User client = userRepository.getReferenceById(clientId);
        Recipe copy = new Recipe();
        copy.setUser(client);
        copy.setOriginSourceId(source.getId());
        copy.setOriginTrainerId(trainerId);
        copyRecipeFields(copy, source, trainerId, clientId, client);

        // The image row FKs to the copy's id, so it must be persisted first.
        Recipe saved = recipeRepository.save(copy);
        copyRecipeImage(saved, source);
        return saved.getId();
    }

    @Override
    public void propagateTemplateUpdate(Long trainerId, Long templateId) {
        WorkoutTemplate source = workoutTemplateRepository.findByIdAndUserId(templateId, trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Workout template not found: " + templateId));

        // One query per assignment — accepted N+1, trainer client rosters and
        // per-user template counts are both small by this feature's existing
        // design assumptions (docs/16-delta-sync-rollout.md).
        for (ContentAssignment assignment : contentAssignmentRepository.findByTrainerIdAndContentTypeAndSourceId(
                trainerId, ContentType.TEMPLATE, templateId)) {
            Long clientId = assignment.getClient().getId();
            // Skip silently if the client already deleted their copy independently —
            // matches unassign()'s handling of the same "copy might be gone" case.
            workoutTemplateRepository.findByIdAndUserId(assignment.getCopiedId(), clientId).ifPresent(copy -> {
                User client = userRepository.getReferenceById(clientId);
                copyTemplateFields(copy, source, trainerId, clientId, client);
                copy.setUpdatedAt(Instant.now());
            });
        }
    }

    @Override
    public void propagateRecipeUpdate(Long trainerId, Long recipeId) {
        Recipe source = recipeRepository.findByIdAndUserId(recipeId, trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Recipe not found: " + recipeId));

        for (ContentAssignment assignment : contentAssignmentRepository.findByTrainerIdAndContentTypeAndSourceId(
                trainerId, ContentType.RECIPE, recipeId)) {
            Long clientId = assignment.getClient().getId();
            recipeRepository.findByIdAndUserId(assignment.getCopiedId(), clientId).ifPresent(copy -> {
                User client = userRepository.getReferenceById(clientId);
                copyRecipeFields(copy, source, trainerId, clientId, client);
                copyRecipeImage(copy, source);
                copy.setUpdatedAt(Instant.now());
            });
        }
    }

    /**
     * Overwrites {@code copy}'s name and exercise list to match {@code source} —
     * shared by the create-new-copy path ({@link #copyTemplateForClient}) and the
     * refresh-existing-copy path ({@link #propagateTemplateUpdate}). Full
     * overwrite: any local edit the client made to their copy is replaced by
     * the trainer's current version (the accepted live-sync tradeoff).
     */
    private void copyTemplateFields(WorkoutTemplate copy, WorkoutTemplate source, Long trainerId, Long clientId, User client) {
        copy.setName(source.getName());
        copy.getExercises().clear();
        for (WorkoutTemplateExercise link : source.getExercises()) {
            Exercise exerciseCopy = resolveExerciseCopy(trainerId, clientId, client, link.getExercise());

            WorkoutTemplateExercise copyLink = new WorkoutTemplateExercise();
            copyLink.setWorkoutTemplate(copy);
            copyLink.setExercise(exerciseCopy);
            copyLink.setTargetSets(link.getTargetSets());
            copyLink.setSortOrder(link.getSortOrder());
            copy.getExercises().add(copyLink);
        }
    }

    /**
     * Overwrites {@code copy}'s name/description/servings and ingredient list
     * to match {@code source} — shared by {@link #copyRecipeForClient} and
     * {@link #propagateRecipeUpdate}. See {@link #copyTemplateFields} for the
     * full-overwrite rationale.
     */
    private void copyRecipeFields(Recipe copy, Recipe source, Long trainerId, Long clientId, User client) {
        copy.setName(source.getName());
        copy.setDescription(source.getDescription());
        copy.setServings(source.getServings());
        copy.getIngredients().clear();
        for (RecipeIngredient ingredient : source.getIngredients()) {
            Food foodCopy = resolveFoodCopy(trainerId, clientId, client, ingredient.getFood());

            RecipeIngredient copyIngredient = new RecipeIngredient();
            copyIngredient.setRecipe(copy);
            copyIngredient.setFood(foodCopy);
            copyIngredient.setQuantityInGrams(ingredient.getQuantityInGrams());
            copy.getIngredients().add(copyIngredient);
        }
    }

    /**
     * Mirrors {@code source}'s photo onto {@code copy} — shared by
     * {@link #copyRecipeForClient} (copy has no image row yet) and
     * {@link #propagateRecipeUpdate} (copy may already have one from a
     * previous assignment/propagation). If the source has no photo, removes
     * the copy's if it has one (e.g. the trainer deleted their photo).
     * Always re-copies when the source has a photo, even if only unrelated
     * recipe fields changed — cheap enough at this data size, and avoids
     * tracking a separate "last synced image version" per assignment.
     */
    private void copyRecipeImage(Recipe copy, Recipe source) {
        Optional<RecipeImage> sourceImage = recipeImageRepository.findByRecipeId(source.getId());
        if (sourceImage.isEmpty()) {
            if (copy.getImageUpdatedAt() != null) {
                recipeImageRepository.deleteByRecipeId(copy.getId());
                copy.setImageUpdatedAt(null);
            }
            return;
        }

        RecipeImage src = sourceImage.get();
        RecipeImage copyImage = recipeImageRepository.findByRecipeId(copy.getId())
                .orElseGet(() -> {
                    RecipeImage created = new RecipeImage();
                    created.setRecipe(copy);
                    return created;
                });
        copyImage.setImage(src.getImage());
        copyImage.setThumbnail(src.getThumbnail());
        copyImage.setContentType(src.getContentType());
        Instant now = Instant.now();
        copyImage.setUpdatedAt(now);
        recipeImageRepository.save(copyImage);
        copy.setImageUpdatedAt(now);
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
                    copy.setDescription(source.getDescription());
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
}
