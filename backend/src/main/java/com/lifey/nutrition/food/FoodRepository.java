package com.lifey.nutrition.food;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface FoodRepository extends JpaRepository<Food, Long> {

    List<Food> findAllByHiddenFalseOrderByName();

    Page<Food> findByHiddenFalse(Pageable pageable);

    Page<Food> findByHiddenFalseAndNameContainingIgnoreCase(String search, Pageable pageable);

    /**
     * Delta-sync feed (docs/15-delta-sync.md) — deliberately not
     * hidden-filtered: it must surface tombstoned rows (hidden = true,
     * deletedAt set) and any edit to an already-hidden shadow food.
     */
    Page<Food> findByUpdatedAtGreaterThanEqual(Instant since, Pageable pageable);

    Optional<Food> findByNameIgnoreCase(String name);

    Optional<Food> findByBarcode(String barcode);
}
