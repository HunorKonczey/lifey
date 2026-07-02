package com.lifey.auth.repository;

import com.lifey.auth.entity.Provider;
import com.lifey.auth.entity.UserIdentity;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface UserIdentityRepository extends JpaRepository<UserIdentity, UUID> {

    Optional<UserIdentity> findByProviderAndProviderUserId(Provider provider, String providerUserId);
}
