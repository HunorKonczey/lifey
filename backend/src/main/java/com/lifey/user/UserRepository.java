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

    /**
     * Backs the super-admin user list search (docs/personal_trainer/03-backend-terv.md).
     * Accent-insensitive on top of case-insensitive — see FoodRepository's equivalent method for the rationale.
     */
    @Query("SELECT u FROM User u "
            + "WHERE cast(function('unaccent', lower(u.email)) as string) "
            + "LIKE cast(function('unaccent', lower(concat('%', :search, '%'))) as string)")
    Page<User> findByEmailContainingIgnoreCase(@Param("search") String search, Pageable pageable);
}
