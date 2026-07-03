package com.lifey.nutrition.food.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodMapper;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;
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
public class FoodServiceImpl implements FoodService {

    private final FoodRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<FoodResponse> findAll() {
        return repository.findAllByUserIdAndHiddenFalseOrderByName(currentUserProvider.getUserId()).stream()
                .map(FoodMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<FoodResponse> findPage(Pageable pageable, String search, Instant updatedSince) {
        Long userId = currentUserProvider.getUserId();
        if (updatedSince != null) {
            // Delta-sync feed: fixed ordering, no hidden filter, no search —
            // see docs/15-delta-sync.md and FoodRepository.findByUserIdAndUpdatedAtGreaterThanEqual.
            Pageable deltaPageable = PageRequest.of(
                    pageable.getPageNumber(),
                    pageable.getPageSize(),
                    Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
            return repository.findByUserIdAndUpdatedAtGreaterThanEqual(userId, updatedSince, deltaPageable)
                    .map(FoodMapper::toResponse);
        }
        Pageable sortedPageable = withNullsLast(pageable);
        Page<Food> page = (search == null || search.isBlank())
                ? repository.findByUserIdAndHiddenFalse(userId, sortedPageable)
                : repository.findByUserIdAndHiddenFalseAndNameContainingIgnoreCase(userId, search.trim(), sortedPageable);
        return page.map(FoodMapper::toResponse);
    }

    /**
     * Metric columns (calories/protein/carbs/fat) are nullable, and the database's
     * default null ordering puts them first on a descending sort — from the user's
     * point of view a food with no data for that column should always sort to the
     * bottom, in either direction, rather than jumping to the top on DESC.
     */
    private static Pageable withNullsLast(Pageable pageable) {
        Sort sort = pageable.getSort();
        if (sort.isUnsorted()) return pageable;
        Sort nullsLastSort = Sort.by(sort.stream().map(Sort.Order::nullsLast).toList());
        return PageRequest.of(pageable.getPageNumber(), pageable.getPageSize(), nullsLastSort);
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
        Food food = FoodMapper.toEntity(request);
        food.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        Food saved = repository.save(food);
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
        repository.findByUserIdAndNameIgnoreCase(currentUserProvider.getUserId(), name)
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
        food.setDeletedAt(Instant.now());
    }

    private Food getOrThrow(Long id) {
        return repository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Food not found: " + id));
    }
}
