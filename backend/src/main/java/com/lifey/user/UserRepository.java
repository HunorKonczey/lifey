package com.lifey.user;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

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
