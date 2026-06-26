package com.lifey.nutrition.meal;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.meal.dto.MealEntryRequest;
import com.lifey.nutrition.meal.dto.MealRequest;
import com.lifey.nutrition.meal.dto.MealResponse;
import com.lifey.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class MealServiceImpl implements MealService {

    private final MealRepository mealRepository;
    private final FoodRepository foodRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    public MealServiceImpl(MealRepository mealRepository, FoodRepository foodRepository,
                           UserRepository userRepository, CurrentUserProvider currentUserProvider) {
        this.mealRepository = mealRepository;
        this.foodRepository = foodRepository;
        this.userRepository = userRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    @Transactional(readOnly = true)
    public List<MealResponse> findAll() {
        return mealRepository.findAllByUserIdOrderByDateTimeDesc(currentUserProvider.getUserId()).stream()
                .map(MealMapper::toResponse)
                .toList();
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
        return MealMapper.toResponse(meal);
    }

    @Override
    public void delete(Long id) {
        Long userId = currentUserProvider.getUserId();
        if (!mealRepository.existsByIdAndUserId(id, userId)) {
            throw new ResourceNotFoundException("Meal not found: " + id);
        }
        mealRepository.deleteByIdAndUserId(id, userId);
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
            Food food = foodRepository.findById(item.foodId())
                    .orElseThrow(() -> new ResourceNotFoundException("Food not found: " + item.foodId()));

            MealEntry entry = new MealEntry();
            entry.setMeal(meal);
            entry.setFood(food);
            entry.setQuantityInGrams(item.quantityInGrams());
            meal.getEntries().add(entry);
        }
    }
}
