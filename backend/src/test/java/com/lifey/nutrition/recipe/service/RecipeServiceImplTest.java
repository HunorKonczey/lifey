package com.lifey.nutrition.recipe.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.domain.BaseEntity;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.recipe.Recipe;
import com.lifey.nutrition.recipe.RecipeIngredient;
import com.lifey.nutrition.recipe.RecipeRepository;
import com.lifey.nutrition.recipe.RecipeUpdatedEvent;
import com.lifey.nutrition.recipe.dto.RecipeIngredientRequest;
import com.lifey.nutrition.recipe.dto.RecipeRequest;
import com.lifey.nutrition.recipe.dto.RecipeResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RecipeServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    RecipeRepository recipeRepository;

    @Mock
    FoodRepository foodRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    ApplicationEventPublisher eventPublisher;

    @InjectMocks
    RecipeServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void create_resolvesFoodsAndReturnsResponse() {
        when(foodRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(food(1L, "Chicken")));
        when(recipeRepository.save(any(Recipe.class))).thenAnswer(inv -> withId(inv.getArgument(0), 7L));
        RecipeRequest request = new RecipeRequest("Chicken & rice", "prep", true, 2,
                List.of(new RecipeIngredientRequest(1L, 200.0)));

        RecipeResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(7L);
        assertThat(result.name()).isEqualTo("Chicken & rice");
        assertThat(result.favorite()).isTrue();
        assertThat(result.servings()).isEqualTo(2);
        assertThat(result.ingredients()).singleElement().satisfies(i -> {
            assertThat(i.foodId()).isEqualTo(1L);
            assertThat(i.foodName()).isEqualTo("Chicken");
            assertThat(i.quantityInGrams()).isEqualTo(200.0);
        });
    }

    @Test
    void create_throwsWhenFoodMissing() {
        when(foodRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        RecipeRequest request = new RecipeRequest("Bad", null, false, null,
                List.of(new RecipeIngredientRequest(99L, 100.0)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Food not found: 99");
    }

    @Test
    void update_rebuildsIngredientList() {
        Recipe existing = new Recipe();
        existing.setId(3L);
        existing.setName("Old");
        RecipeIngredient old = new RecipeIngredient();
        old.setRecipe(existing);
        old.setFood(food(2L, "Rice"));
        old.setQuantityInGrams(50.0);
        existing.getIngredients().add(old);

        when(recipeRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));
        when(foodRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(food(1L, "Chicken")));
        RecipeRequest request = new RecipeRequest("New", "desc", true, null,
                List.of(new RecipeIngredientRequest(1L, 300.0)));

        RecipeResponse result = service.update(3L, request);

        assertThat(result.name()).isEqualTo("New");
        assertThat(result.favorite()).isTrue();
        assertThat(result.servings()).isEqualTo(1); // null servings defaults to 1
        assertThat(existing.isFavorite()).isTrue();
        assertThat(result.ingredients()).singleElement().satisfies(i -> {
            assertThat(i.foodId()).isEqualTo(1L);
            assertThat(i.quantityInGrams()).isEqualTo(300.0);
        });
        // old ingredient replaced (orphanRemoval handles deletion at flush)
        assertThat(existing.getIngredients()).hasSize(1);
    }

    @Test
    void update_publishesUpdatedEventForLiveSync() {
        Recipe existing = new Recipe();
        existing.setId(3L);
        existing.setName("Old");
        when(recipeRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));
        when(foodRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(food(1L, "Chicken")));

        service.update(3L, new RecipeRequest("New", null, false, 1,
                List.of(new RecipeIngredientRequest(1L, 300.0))));

        ArgumentCaptor<RecipeUpdatedEvent> captor = ArgumentCaptor.forClass(RecipeUpdatedEvent.class);
        verify(eventPublisher).publishEvent(captor.capture());
        assertThat(captor.getValue().trainerId()).isEqualTo(USER_ID);
        assertThat(captor.getValue().recipeId()).isEqualTo(3L);
    }

    @Test
    void findById_throwsWhenMissing() {
        when(recipeRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.findById(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void findAll_returnsFavoritesFirstInRepositoryOrder() {
        Recipe favorite = recipe(1L, "Apple pie", true);
        Recipe nonFavorite = recipe(2L, "Banana bread", false);
        // The repository's ORDER BY favorite DESC, name ASC is what actually
        // ranks favorites first; the service just needs to preserve that order.
        when(recipeRepository.findAllByUserIdAndDeletedAtIsNullOrderByFavoriteDescNameAsc(USER_ID))
                .thenReturn(List.of(favorite, nonFavorite));

        List<RecipeResponse> result = service.findAll();

        assertThat(result).extracting(RecipeResponse::name, RecipeResponse::favorite)
                .containsExactly(tuple("Apple pie", true), tuple("Banana bread", false));
    }

    @Test
    void delete_throwsWhenMissing() {
        when(recipeRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_setsDeletedAtInsteadOfRemovingRow() {
        Recipe existing = recipe(1L, "Apple pie", false);
        when(recipeRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(existing));

        service.delete(1L);

        assertThat(existing.getDeletedAt()).isNotNull();
    }

    @Test
    void update_ingredientOnlyEditBumpsParentUpdatedAt() {
        Recipe existing = new Recipe();
        existing.setId(3L);
        existing.setName("Old");
        existing.setUpdatedAt(Instant.parse("2026-06-18T08:00:00Z"));
        RecipeIngredient old = new RecipeIngredient();
        old.setRecipe(existing);
        old.setFood(food(2L, "Rice"));
        old.setQuantityInGrams(50.0);
        existing.getIngredients().add(old);

        when(recipeRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));
        when(foodRepository.findByIdAndUserId(2L, USER_ID)).thenReturn(Optional.of(food(2L, "Rice")));

        // Same name/description/favorite/servings as before — only the ingredient quantity differs.
        RecipeRequest request = new RecipeRequest("Old", null, false, 1,
                List.of(new RecipeIngredientRequest(2L, 150.0)));

        service.update(3L, request);

        assertThat(existing.getUpdatedAt()).isAfter(Instant.parse("2026-06-18T08:00:00Z"));
    }

    @Test
    void findPage_noSearch_usesDeletedAtIsNullQuery() {
        Pageable pageable = PageRequest.of(0, 2);
        Page<Recipe> page = new PageImpl<>(List.of(recipe(1L, "Apple pie", false)), pageable, 1);
        when(recipeRepository.findByUserIdAndDeletedAtIsNull(USER_ID, pageable)).thenReturn(page);

        Page<RecipeResponse> result = service.findPage(pageable, null);

        assertThat(result.getContent()).singleElement()
                .satisfies(r -> assertThat(r.name()).isEqualTo("Apple pie"));
        verify(recipeRepository, never())
                .findByUserIdAndDeletedAtIsNullAndNameContainingIgnoreCase(any(), any(), any());
    }

    @Test
    void findPage_blankSearch_treatedAsNoSearch() {
        Pageable pageable = PageRequest.of(0, 2);
        when(recipeRepository.findByUserIdAndDeletedAtIsNull(USER_ID, pageable)).thenReturn(Page.empty(pageable));

        service.findPage(pageable, "   ");

        verify(recipeRepository).findByUserIdAndDeletedAtIsNull(USER_ID, pageable);
        verify(recipeRepository, never())
                .findByUserIdAndDeletedAtIsNullAndNameContainingIgnoreCase(any(), any(), any());
    }

    @Test
    void findPage_withSearch_usesSearchQueryAndTrimsIt() {
        Pageable pageable = PageRequest.of(0, 10);
        Page<Recipe> page = new PageImpl<>(List.of(recipe(2L, "Banana bread", false)), pageable, 1);
        when(recipeRepository.findByUserIdAndDeletedAtIsNullAndNameContainingIgnoreCase(
                USER_ID, "banana", pageable)).thenReturn(page);

        Page<RecipeResponse> result = service.findPage(pageable, "  banana  ");

        assertThat(result.getContent()).singleElement()
                .satisfies(r -> assertThat(r.name()).isEqualTo("Banana bread"));
        verify(recipeRepository, never()).findByUserIdAndDeletedAtIsNull(any(), any());
    }

    @Test
    void findDelta_isUserScopedAndIncludesTombstones() {
        Recipe deleted = recipe(2L, "Deleted recipe", false);
        deleted.setDeletedAt(Instant.parse("2026-06-19T00:00:00Z"));

        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        Pageable requested = PageRequest.of(0, 50);
        Page<Recipe> page = new PageImpl<>(List.of(deleted));
        when(recipeRepository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any()))
                .thenReturn(page);

        Page<RecipeResponse> result = service.findDelta(since, requested);

        assertThat(result.getContent()).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(2L);
            assertThat(r.deletedAt()).isEqualTo(deleted.getDeletedAt());
        });
    }

    private static Recipe recipe(Long id, String name, boolean favorite) {
        Recipe r = new Recipe();
        r.setId(id);
        r.setName(name);
        r.setFavorite(favorite);
        return r;
    }

    private static Food food(Long id, String name) {
        Food f = new Food();
        f.setId(id);
        f.setName(name);
        f.setCaloriesPer100g(100);
        f.setProteinPer100g(10);
        return f;
    }

    private static <T extends BaseEntity> T withId(T entity, Long id) {
        entity.setId(id);
        return entity;
    }
}
