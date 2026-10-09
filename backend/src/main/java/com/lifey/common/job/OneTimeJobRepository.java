package com.lifey.common.job;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

public interface OneTimeJobRepository extends JpaRepository<OneTimeJob, String> {

    /**
     * Takes the job for {@code until} - one statement, so of two instances racing for it exactly one gets 1. A completed job is
     * never claimed again; a job whose lease has run out (its runner died) is.
     *
     * @return 1 when this caller now holds the job, 0 when it is done or somebody else holds it
     */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update OneTimeJob j set j.claimedUntil = :until "
            + "where j.name = :name and j.completedAt is null and (j.claimedUntil is null or j.claimedUntil < :now)")
    int claim(@Param("name") String name, @Param("now") Instant now, @Param("until") Instant until);

    /** Records how far the job got and what it did since the last call, and moves the lease ({@code null} releases it). */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update OneTimeJob j set j.cursorId = :cursor, j.processedCount = j.processedCount + :processed, "
            + "j.filledCount = j.filledCount + :filled, j.claimedUntil = :lease where j.name = :name")
    int saveProgress(@Param("name") String name, @Param("cursor") long cursor, @Param("processed") int processed,
                     @Param("filled") int filled, @Param("lease") Instant lease);

    /** Ends the job for good and releases the lease. */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update OneTimeJob j set j.completedAt = :now, j.claimedUntil = null where j.name = :name and j.completedAt is null")
    int complete(@Param("name") String name, @Param("now") Instant now);
}
