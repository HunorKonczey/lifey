package com.lifey.nutrition.meal.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.domain.BaseEntity;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.meal.Meal;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.nutrition.meal.MealType;
import com.lifey.nutrition.meal.dto.MealEntryRequest;
import com.lifey.nutrition.meal.dto.MealRequest;
import com.lifey.nutrition.meal.dto.MealResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.time.LocalDate;
import java.time.Month;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
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
        when(foodRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(food(1L, "Oats")));
        when(mealRepository.save(any(Meal.class))).thenAnswer(inv -> withId(inv.getArgument(0), 4L));
        MealRequest request = new MealRequest(
                Instant.parse("2026-06-18T08:00:00Z"), MealType.BREAKFAST, null,
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
        when(foodRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        MealRequest request = new MealRequest(
                Instant.parse("2026-06-18T08:00:00Z"), MealType.SNACK, null,
                List.of(new MealEntryRequest(99L, 50.0)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Food not found: 99");
    }

    @Test
    void delete_throwsWhenMissing() {
        when(mealRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_setsDeletedAtInsteadOfRemovingRow() {
        Meal meal = new Meal();
        meal.setId(1L);
        when(mealRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(meal));

        service.delete(1L);

        assertThat(meal.getDeletedAt()).isNotNull();
    }

    @Test
    void update_entryOnlyEditBumpsParentUpdatedAt() {
        Meal meal = new Meal();
        meal.setId(1L);
        meal.setDateTime(Instant.parse("2026-06-18T08:00:00Z"));
        meal.setMealType(MealType.BREAKFAST);
        meal.setUpdatedAt(Instant.parse("2026-06-18T08:00:00Z"));
        when(mealRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(meal));
        when(foodRepository.findByIdAndUserId(2L, USER_ID)).thenReturn(Optional.of(food(2L, "Rice")));

        // Same dateTime/mealType/name as before — only the entries differ.
        MealRequest request = new MealRequest(
                Instant.parse("2026-06-18T08:00:00Z"), MealType.BREAKFAST, null,
                List.of(new MealEntryRequest(2L, 150.0)));

        service.update(1L, request);

        assertThat(meal.getUpdatedAt()).isAfter(Instant.parse("2026-06-18T08:00:00Z"));
    }

    @Test
    void findAllForUserBetween_usesTargetUsersOwnUtcOffsetForDayBoundaries() {
        User client = new User();
        client.setId(USER_ID);
        client.setUtcOffsetMinutes(120); // e.g. Budapest summer time, UTC+2
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(client));
        when(mealRepository.findAllByUserIdAndDeletedAtIsNullAndDateTimeRange(eq(USER_ID), any(), any()))
                .thenReturn(List.of());

        service.findAllForUserBetween(USER_ID, LocalDate.of(2026, Month.JULY, 6), LocalDate.of(2026, Month.JULY, 6));

        ArgumentCaptor<Instant> fromCaptor = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<Instant> toCaptor = ArgumentCaptor.forClass(Instant.class);
        verify(mealRepository).findAllByUserIdAndDeletedAtIsNullAndDateTimeRange(
                eq(USER_ID), fromCaptor.capture(), toCaptor.capture());

        // Local midnight in UTC+2 is 22:00 UTC the day before — a meal logged at
        // 00:21 local (22:21 UTC the day before) must fall inside this window,
        // which the old ZoneId.systemDefault() bug missed for non-UTC servers.
        assertThat(fromCaptor.getValue()).isEqualTo(Instant.parse("2026-07-05T22:00:00Z"));
        assertThat(toCaptor.getValue()).isEqualTo(Instant.parse("2026-07-06T22:00:00Z"));
    }

    @Test
    void findDelta_isUserScopedAndIncludesTombstones() {
        Meal deleted = new Meal();
        deleted.setId(2L);
        deleted.setDeletedAt(Instant.parse("2026-06-19T00:00:00Z"));

        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        Pageable requested = PageRequest.of(0, 50);
        Page<Meal> page = new PageImpl<>(List.of(deleted));
        when(mealRepository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any()))
                .thenReturn(page);

        Page<MealResponse> result = service.findDelta(since, requested);

        assertThat(result.getContent()).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(2L);
            assertThat(r.deletedAt()).isEqualTo(deleted.getDeletedAt());
        });
    }

    private static Food food(Long id, String name) {
        Food f = new Food();
        f.setId(id);
        f.setName(name);
        f.setCaloriesPer100g(389);
        f.setProteinPer100g(17);
        return f;
    }

    private static <T extends BaseEntity> T withId(T entity, Long id) {
        entity.setId(id);
        return entity;
    }
}
