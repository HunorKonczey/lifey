package com.lifey.nutrition.food;

import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class FoodServiceImpl implements FoodService {

    private final FoodRepository repository;

    public FoodServiceImpl(FoodRepository repository) {
        this.repository = repository;
    }

    @Override
    @Transactional(readOnly = true)
    public List<FoodResponse> findAll() {
        return repository.findAllByHiddenFalseOrderByName().stream()
                .map(FoodMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public FoodResponse findById(Long id) {
        return FoodMapper.toResponse(getOrThrow(id));
    }

    @Override
    public FoodResponse create(FoodRequest request) {
        if (!request.hidden()) {
            requireUniqueName(request.name().trim(), null);
        }
        Food saved = repository.save(FoodMapper.toEntity(request));
        return FoodMapper.toResponse(saved);
    }

    @Override
    public FoodResponse update(Long id, FoodRequest request) {
        Food food = getOrThrow(id);
        if (!request.hidden()) {
            requireUniqueName(request.name().trim(), id);
        }
        FoodMapper.apply(food, request);
        return FoodMapper.toResponse(food);
    }

    /**
     * Foods are matched by name (case-insensitive) when logging meals and recipes,
     * so two entries with the same name would be indistinguishable in those pickers.
     * Hidden foods (recipe/meal ingredient shadows) are excluded: they are never
     * shown in pickers, so a hidden "Egg" must not block a visible food named "Egg".
     */
    private void requireUniqueName(String name, Long ignoreId) {
        repository.findByNameIgnoreCase(name)
                .filter(existing -> !existing.isHidden())
                .filter(existing -> !existing.getId().equals(ignoreId))
                .ifPresent(_ -> {
                    throw new DuplicateResourceException("A food named '" + name + "' already exists");
                });
    }

    /**
     * Soft-deletes the food by setting {@code hidden = true} instead of removing
     * the row. Hard deletion would violate the FK on {@code meal_entries.food_id}
     * whenever the food has ever been logged — which is the normal case for any
     * food the user has actually used. Setting hidden removes the food from all
     * catalogue pickers while keeping historical meal/recipe data intact.
     */
    @Override
    public void delete(Long id) {
        Food food = getOrThrow(id);
        food.setHidden(true);
    }

    private Food getOrThrow(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Food not found: " + id));
    }
}
