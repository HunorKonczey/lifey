package com.lifey.trainer.request;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface TrainerRequestRepository extends JpaRepository<TrainerRequest, Long> {

    Optional<TrainerRequest> findFirstByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<TrainerRequest> findFirstByUserIdAndStatus(Long userId, TrainerRequestStatus status);

    boolean existsByUserIdAndStatus(Long userId, TrainerRequestStatus status);

    /** {@code join fetch} avoids an N+1 on {@code user} — the superadmin list always needs the requester's email. */
    @Query(value = "select tr from TrainerRequest tr join fetch tr.user where tr.status = :status",
            countQuery = "select count(tr) from TrainerRequest tr where tr.status = :status")
    Page<TrainerRequest> findByStatus(@Param("status") TrainerRequestStatus status, Pageable pageable);
}
