package com.lifey.weight;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface WeightEntryRepository extends JpaRepository<WeightEntry, Long> {

    List<WeightEntry> findAllByOrderByDateDesc();

    Optional<WeightEntry> findFirstByOrderByDateDesc();
}
