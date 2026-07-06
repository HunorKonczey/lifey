package com.lifey.user;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    /** Backs the super-admin user list search (docs/personal_trainer/03-backend-terv.md). */
    Page<User> findByEmailContainingIgnoreCase(String search, Pageable pageable);
}
