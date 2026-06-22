package com.lifey.nutrition.recipe;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.recipe.dto.RecipeIngredientRequest;
import com.lifey.nutrition.recipe.dto.RecipeRequest;
import com.lifey.nutrition.recipe.dto.RecipeResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

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

    @InjectMocks
    RecipeServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void create_resolvesFoodsAndReturnsResponse() {
        when(foodRepository.findById(1L)).thenReturn(Optional.of(food(1L, "Chicken")));
        when(recipeRepository.save(any(Recipe.class))).thenAnswer(inv -> {
            Recipe r = inv.getArgument(0);
            r.setId(7L);
            return r;
        });
        RecipeRequest request = new RecipeRequest("Chicken & rice", "prep", true,
                List.of(new RecipeIngredientRequest(1L, 200.0)));

        RecipeResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(7L);
        assertThat(result.name()).isEqualTo("Chicken & rice");
        assertThat(result.favorite()).isTrue();
        assertThat(result.ingredients()).singleElement().satisfies(i -> {
            assertThat(i.foodId()).isEqualTo(1L);
            assertThat(i.foodName()).isEqualTo("Chicken");
            assertThat(i.quantityInGrams()).isEqualTo(200.0);
        });
    }

    @Test
    void create_throwsWhenFoodMissing() {
        when(foodRepository.findById(99L)).thenReturn(Optional.empty());
        RecipeRequest request = new RecipeRequest("Bad", null, false,
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
        when(foodRepository.findById(1L)).thenReturn(Optional.of(food(1L, "Chicken")));
        RecipeRequest request = new RecipeRequest("New", "desc", true,
                List.of(new RecipeIngredientRequest(1L, 300.0)));

        RecipeResponse result = service.update(3L, request);

        assertThat(result.name()).isEqualTo("New");
        assertThat(result.favorite()).isTrue();
        assertThat(existing.isFavorite()).isTrue();
        assertThat(result.ingredients()).singleElement().satisfies(i -> {
            assertThat(i.foodId()).isEqualTo(1L);
            assertThat(i.quantityInGrams()).isEqualTo(300.0);
        });
        // old ingredient replaced (orphanRemoval handles deletion at flush)
        assertThat(existing.getIngredients()).hasSize(1);
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
        when(recipeRepository.findAllByUserIdOrderByFavoriteDescNameAsc(USER_ID))
                .thenReturn(List.of(favorite, nonFavorite));

        List<RecipeResponse> result = service.findAll();

        assertThat(result).extracting(RecipeResponse::name)
                .containsExactly("Apple pie", "Banana bread");
        assertThat(result).extracting(RecipeResponse::favorite)
                .containsExactly(true, false);
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
}
