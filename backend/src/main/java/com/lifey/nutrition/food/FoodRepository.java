package com.lifey.nutrition.food;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface FoodRepository extends JpaRepository<Food, Long> {

    List<Food> findAllByHiddenFalseOrderByName();

    Optional<Food> findByNameIgnoreCase(String name);

    Optional<Food> findByBarcode(String barcode);
}
