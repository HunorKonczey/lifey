package com.lifey.user;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    /**
     * Stamps {@code last_active_at} unless it is already newer than {@code threshold}, so several instances (or a
     * burst of requests) still write a user about once per throttle window. Returns the rows changed (0 or 1).
     */
    @Transactional
    @Modifying
    @Query("UPDATE User u SET u.lastActiveAt = :now WHERE u.id = :id AND (u.lastActiveAt IS NULL OR u.lastActiveAt < :threshold)")
    int touchLastActive(@Param("id") Long id, @Param("now") Instant now, @Param("threshold") Instant threshold);

    /**
     * Accounts active since {@code since}: a request stamped in {@code last_active_at}, OR a sign-in/session refresh
     * (the activity the server recorded before the column existed — kept so the figure does not drop to zero on the day
     * the column ships; docs/redesign-web/82 section 2.3).
     */
    @Query("""
            SELECT count(u) FROM User u
            WHERE u.lastActiveAt > :since
               OR EXISTS (SELECT 1 FROM RefreshToken rt WHERE rt.user = u AND rt.createdAt > :since)
            """)
    long countActiveSince(@Param("since") Instant since);

    /** Super-admin stats: accounts holding a role. */
    @Query("select count(u) from User u where :role member of u.roles")
    long countByRole(@Param("role") Role role);

    /**
     * Backs the super-admin user list search (docs/personal_trainer/03-backend-terv.md).
     * Accent-insensitive on top of case-insensitive — see FoodRepository's equivalent method for the rationale.
     */
    @Query("SELECT u FROM User u "
            + "WHERE cast(function('unaccent', lower(u.email)) as string) "
            + "LIKE cast(function('unaccent', lower(concat('%', :search, '%'))) as string)")
    Page<User> findByEmailContainingIgnoreCase(@Param("search") String search, Pageable pageable);

    /**
     * The super-admin list filtered by the role a user is shown as ({@code kind} is a {@code UserRoleKind} name —
     * a string, never null, so Postgres can type the parameter). {@code search} is the e-mail fragment, empty for
     * "everyone". Precedence mirrors the web table: ADMIN (admin or super-admin) over TRAINER over USER.
     */
    @Query("""
            SELECT u FROM User u
            WHERE cast(function('unaccent', lower(u.email)) as string)
                  LIKE cast(function('unaccent', lower(concat('%', :search, '%'))) as string)
              AND (
                   (:kind = 'ADMIN' AND (com.lifey.user.Role.ROLE_ADMIN MEMBER OF u.roles
                                         OR com.lifey.user.Role.ROLE_SUPER_ADMIN MEMBER OF u.roles))
                OR (:kind = 'TRAINER' AND com.lifey.user.Role.ROLE_TRAINER MEMBER OF u.roles
                                      AND com.lifey.user.Role.ROLE_ADMIN NOT MEMBER OF u.roles
                                      AND com.lifey.user.Role.ROLE_SUPER_ADMIN NOT MEMBER OF u.roles)
                OR (:kind = 'USER' AND com.lifey.user.Role.ROLE_TRAINER NOT MEMBER OF u.roles
                                   AND com.lifey.user.Role.ROLE_ADMIN NOT MEMBER OF u.roles
                                   AND com.lifey.user.Role.ROLE_SUPER_ADMIN NOT MEMBER OF u.roles)
              )
            """)
    Page<User> findByRoleKind(@Param("search") String search, @Param("kind") String kind, Pageable pageable);
}
