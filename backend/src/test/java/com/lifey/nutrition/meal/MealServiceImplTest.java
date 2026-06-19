package com.lifey.nutrition.meal;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.meal.dto.MealEntryRequest;
import com.lifey.nutrition.meal.dto.MealRequest;
import com.lifey.nutrition.meal.dto.MealResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MealServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    MealRepository mealRepository;

    @Mock
    FoodRepository foodRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    MealServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void create_resolvesFoodsAndReturnsResponse() {
        when(foodRepository.findById(1L)).thenReturn(Optional.of(food(1L, "Oats")));
        when(mealRepository.save(any(Meal.class))).thenAnswer(inv -> {
            Meal m = inv.getArgument(0);
            m.setId(4L);
            return m;
        });
        MealRequest request = new MealRequest(
                LocalDateTime.of(2026, 6, 18, 8, 0), MealType.BREAKFAST,
                List.of(new MealEntryRequest(1L, 80.0)));

        MealResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(4L);
        assertThat(result.mealType()).isEqualTo(MealType.BREAKFAST);
        assertThat(result.entries()).singleElement().satisfies(e -> {
            assertThat(e.foodId()).isEqualTo(1L);
            assertThat(e.foodName()).isEqualTo("Oats");
            assertThat(e.quantityInGrams()).isEqualTo(80.0);
        });
    }

    @Test
    void create_throwsWhenFoodMissing() {
        when(foodRepository.findById(99L)).thenReturn(Optional.empty());
        MealRequest request = new MealRequest(
                LocalDateTime.of(2026, 6, 18, 8, 0), MealType.SNACK,
                List.of(new MealEntryRequest(99L, 50.0)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Food not found: 99");
    }

    @Test
    void delete_throwsWhenMissing() {
        when(mealRepository.existsByIdAndUserId(99L, USER_ID)).thenReturn(false);

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(mealRepository, never()).deleteByIdAndUserId(any(), any());
    }

    private static Food food(Long id, String name) {
        Food f = new Food();
        f.setId(id);
        f.setName(name);
        f.setCaloriesPer100g(389);
        f.setProteinPer100g(17);
        return f;
    }
}
