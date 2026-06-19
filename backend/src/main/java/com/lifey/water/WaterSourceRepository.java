package com.lifey.water;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface WaterSourceRepository extends JpaRepository<WaterSource, Long> {

    List<WaterSource> findAllByUserId(Long userId);

    Optional<WaterSource> findByIdAndUserId(Long id, Long userId);

    boolean existsByIdAndUserId(Long id, Long userId);

    void deleteByIdAndUserId(Long id, Long userId);
}
