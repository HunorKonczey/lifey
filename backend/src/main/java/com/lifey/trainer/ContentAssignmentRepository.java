package com.lifey.trainer;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ContentAssignmentRepository extends JpaRepository<ContentAssignment, Long> {

    List<ContentAssignment> findByTrainerIdAndClientIdOrderByAssignedAtDesc(Long trainerId, Long clientId);

    boolean existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
            Long trainerId, Long clientId, ContentType contentType, Long sourceId);

    /** Backs the client-card "assigned plans" count (docs/personal_trainer/06-design.md §3.2). */
    long countByTrainerIdAndClientId(Long trainerId, Long clientId);
}
