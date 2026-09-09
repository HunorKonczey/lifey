package com.lifey.billing.repository;

import com.lifey.billing.entity.AiUsageCounter;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface AiUsageCounterRepository extends JpaRepository<AiUsageCounter, Long> {

    Optional<AiUsageCounter> findByUserIdAndYearMonth(Long userId, String yearMonth);

    /**
     * The atomic increment (docs/landing_page/64-billing-backend-plan.md §3.4) — a
     * Postgres upsert rather than JPA's usual load-mutate-save, since two AI calls
     * from the same user landing in the same month at the same time must not race
     * and silently lose one. {@code clearAutomatically}: this native query bypasses
     * the persistence context, so a stale cached row would otherwise survive a
     * later {@link #findByUserIdAndYearMonth} in the same transaction.
     */
    @Modifying(clearAutomatically = true)
    @Query(value = "insert into ai_usage_counter (user_id, year_month, used_count) "
            + "values (:userId, :yearMonth, 1) "
            + "on conflict (user_id, year_month) "
            + "do update set used_count = ai_usage_counter.used_count + 1",
            nativeQuery = true)
    void incrementUsage(@Param("userId") Long userId, @Param("yearMonth") String yearMonth);
}
