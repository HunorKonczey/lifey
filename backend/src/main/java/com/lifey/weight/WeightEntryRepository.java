package com.lifey.weight;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface WeightEntryRepository extends JpaRepository<WeightEntry, Long> {

    List<WeightEntry> findAllByUserIdOrderByDateDescRecordedAtDesc(Long userId);

    Optional<WeightEntry> findFirstByUserIdOrderByDateDescRecordedAtDesc(Long userId);

    boolean existsByIdAndUserId(Long id, Long userId);

    void deleteByIdAndUserId(Long id, Long userId);
}
