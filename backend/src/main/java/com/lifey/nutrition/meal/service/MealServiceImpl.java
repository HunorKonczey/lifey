package com.lifey.nutrition.meal.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.meal.Meal;
import com.lifey.nutrition.meal.MealEntry;
import com.lifey.nutrition.meal.MealMapper;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.nutrition.meal.dto.MealEntryRequest;
import com.lifey.nutrition.meal.dto.MealRequest;
import com.lifey.nutrition.meal.dto.MealResponse;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional
public class MealServiceImpl implements MealService {

    private final MealRepository mealRepository;
    private final FoodRepository foodRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<MealResponse> findAll() {
        return mealRepository.findAllByUserIdAndDeletedAtIsNullOrderByDateTimeDesc(currentUserProvider.getUserId()).stream()
                .map(MealMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<MealResponse> findDelta(Instant updatedSince, Pageable pageable) {
        // Delta-sync feed: fixed ordering, includes tombstoned rows — see
        // docs/16-delta-sync-rollout.md and MealRepository.findByUserIdAndUpdatedAtGreaterThanEqual.
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return mealRepository.findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(MealMapper::toResponse);
    }

    @Override
    public MealResponse create(MealRequest request) {
        Meal meal = new Meal();
        meal.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        meal.setDateTime(request.dateTime());
        meal.setMealType(request.mealType());
        meal.setName(request.name());
        replaceEntries(meal, request.entries());
        return MealMapper.toResponse(mealRepository.save(meal));
    }

    @Override
    public MealResponse update(Long id, MealRequest request) {
        Meal meal = getOrThrow(id);
        meal.setDateTime(request.dateTime());
        meal.setMealType(request.mealType());
        meal.setName(request.name());
        replaceEntries(meal, request.entries());
        // Entries are child rows with no delta feed of their own (docs/16 §2.3) — an
        // entry-only edit (e.g. grams changed, food swapped, dateTime/mealType/name
        // unchanged) would leave Meal's own scalar fields untouched, so Hibernate's
        // dirty-checking could skip @PreUpdate. Bump explicitly so it always fires.
        meal.setUpdatedAt(Instant.now());
        return MealMapper.toResponse(meal);
    }

    @Override
    public void delete(Long id) {
        Meal meal = getOrThrow(id);
        meal.setDeletedAt(Instant.now());
    }

    private Meal getOrThrow(Long id) {
        return mealRepository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Meal not found: " + id));
    }

    /**
     * Rebuilds the meal's entry list from the request, resolving each {@code foodId}.
     * Relies on {@code orphanRemoval} to delete dropped entries.
     */
    private void replaceEntries(Meal meal, List<MealEntryRequest> requested) {
        meal.getEntries().clear();
        for (MealEntryRequest item : requested) {
            Food food = foodRepository.findByIdAndUserId(item.foodId(), currentUserProvider.getUserId())
                    .orElseThrow(() -> new ResourceNotFoundException("Food not found: " + item.foodId()));

            MealEntry entry = new MealEntry();
            entry.setMeal(meal);
            entry.setFood(food);
            entry.setQuantityInGrams(item.quantityInGrams());
            meal.getEntries().add(entry);
        }
    }
}
