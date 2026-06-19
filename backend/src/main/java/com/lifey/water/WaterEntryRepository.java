package com.lifey.water;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

public interface WaterEntryRepository extends JpaRepository<WaterEntry, Long> {

    List<WaterEntry> findAllByUserIdOrderByConsumedAtDesc(Long userId);

    boolean existsByIdAndUserId(Long id, Long userId);

    void deleteByIdAndUserId(Long id, Long userId);

    @Query("""
            select coalesce(sum(e.volumeLiters), 0)
            from WaterEntry e
            where e.user.id = :userId and e.consumedAt >= :from
            """)
    double sumVolumeLitersSince(@Param("userId") Long userId, @Param("from") Instant from);
}
