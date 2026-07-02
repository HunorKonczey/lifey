package com.lifey.water;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface WaterEntryRepository extends JpaRepository<WaterEntry, Long> {

    List<WaterEntry> findAllByUserIdAndDeletedAtIsNullOrderByConsumedAtDesc(Long userId);

    Optional<WaterEntry> findByIdAndUserId(Long id, Long userId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<WaterEntry> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);

    @Query("""
            select coalesce(sum(e.volumeLiters), 0)
            from WaterEntry e
            where e.user.id = :userId and e.consumedAt >= :from and e.deletedAt is null
            """)
    double sumVolumeLitersSince(@Param("userId") Long userId, @Param("from") Instant from);
}
