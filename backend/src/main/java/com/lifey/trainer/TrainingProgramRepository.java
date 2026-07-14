package com.lifey.trainer;

import com.lifey.trainer.entity.TrainingProgram;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface TrainingProgramRepository extends JpaRepository<TrainingProgram, Long> {

    List<TrainingProgram> findByUserIdAndDeletedAtIsNullOrderByCreatedAtDesc(Long userId);

    /** Ownership-scoped lookup for program reads/mutations — empty (not a 403) if it belongs to another trainer. */
    Optional<TrainingProgram> findByIdAndUserIdAndDeletedAtIsNull(Long id, Long userId);
}
