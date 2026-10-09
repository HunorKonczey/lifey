package com.lifey.trainer;

import com.lifey.trainer.entity.ContentAssignment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ContentAssignmentRepository extends JpaRepository<ContentAssignment, Long> {

    List<ContentAssignment> findByTrainerIdAndClientIdOrderByAssignedAtDesc(Long trainerId, Long clientId);

    boolean existsByTrainerIdAndClientIdAndContentTypeAndSourceId(
            Long trainerId, Long clientId, ContentType contentType, Long sourceId);

    /** Backs the client-card "assigned plans" count (docs/personal_trainer/06-design.md §3.2). */
    long countByTrainerIdAndClientId(Long trainerId, Long clientId);

    /** Backs the assign-drawer's "already assigned" pre-checked clients. */
    List<ContentAssignment> findByTrainerIdAndContentTypeAndSourceId(
            Long trainerId, ContentType contentType, Long sourceId);

    Optional<ContentAssignment> findByIdAndTrainerId(Long id, Long trainerId);

    /** One (template, client) pair per template this trainer assigned - the "assigned" half of the usage view (LIF-106). */
    @Query("select a.sourceId as templateId, a.client.id as clientId from ContentAssignment a "
            + "where a.trainer.id = :trainerId and a.contentType = :type")
    List<TemplateClientPair> findAssignedPairs(@Param("trainerId") Long trainerId, @Param("type") ContentType type);
}
