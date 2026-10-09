package com.lifey.nutrition.food.backfill;

import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * One food's write, in its own transaction: the backfill does an HTTP call per food, so it must not hold a transaction (and a
 * connection) across them - and one food's failure must not roll back the ones before it.
 */
@Component
@RequiredArgsConstructor
class FoodBackfillWriter {

    private final FoodRepository foodRepository;

    /**
     * Fills the fibre and sugar the food does not have yet - never overwriting a figure it has (the user or the web may have set
     * it since the batch was read). Saving bumps {@code updatedAt}, which is what delta sync hands to the phones.
     *
     * @return how many of the two figures were filled (0 when the food is gone, deleted, or already complete)
     */
    @Transactional
    public int fill(long foodId, Double fiberPer100g, Double sugarPer100g) {
        Food food = foodRepository.findById(foodId).orElse(null);
        if (food == null || food.getDeletedAt() != null) {
            return 0;
        }
        int filled = 0;
        if (food.getFiberPer100g() == null && fiberPer100g != null) {
            food.setFiberPer100g(fiberPer100g);
            filled++;
        }
        if (food.getSugarPer100g() == null && sugarPer100g != null) {
            food.setSugarPer100g(sugarPer100g);
            filled++;
        }
        return filled;
    }
}
