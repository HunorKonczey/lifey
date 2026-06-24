package com.lifey.steps;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface DailyStepCountRepository extends JpaRepository<DailyStepCount, Long> {

    List<DailyStepCount> findAllByUserIdOrderByDateDesc(Long userId);

    Optional<DailyStepCount> findByUserIdAndDate(Long userId, LocalDate date);

    boolean existsByIdAndUserId(Long id, Long userId);

    void deleteByIdAndUserId(Long id, Long userId);
}
