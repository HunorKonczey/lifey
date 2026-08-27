package com.lifey.billing.repository;

import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.dao.DataIntegrityViolationException;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Repository slice for {@link Subscription} — every provider round-trips, and
 * both unique constraints from V73 (docs/landing_page/64-billing-backend-plan.md
 * §8) actually reject duplicates.
 */
@SpringBootTest
@Testcontainers
class SubscriptionRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    SubscriptionRepository subscriptionRepository;

    @ParameterizedTest
    @EnumSource(SubscriptionProvider.class)
    void savesAndReadsBackARowOfEachProvider(SubscriptionProvider provider) {
        Long userId = saveUser("subscription-" + provider + "-" + System.nanoTime() + "@example.com").getId();

        Subscription subscription = newSubscription(userId, provider, SubscriptionStatus.ACTIVE);
        Long savedId = subscriptionRepository.save(subscription).getId();

        Optional<Subscription> reloaded = subscriptionRepository.findById(savedId);
        assertThat(reloaded).isPresent();
        assertThat(reloaded.get().getUser().getId()).isEqualTo(userId);
        assertThat(reloaded.get().getProvider()).isEqualTo(provider);
        assertThat(reloaded.get().getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
        assertThat(reloaded.get().getCreatedAt()).isNotNull();
        assertThat(reloaded.get().getUpdatedAt()).isNotNull();
    }

    @Test
    void findByUserId_returnsEveryProviderRowForThatUser() {
        Long userId = saveUser("subscription-multi-" + System.nanoTime() + "@example.com").getId();
        subscriptionRepository.save(newSubscription(userId, SubscriptionProvider.STRIPE, SubscriptionStatus.ACTIVE));
        subscriptionRepository.save(newSubscription(userId, SubscriptionProvider.APP_STORE, SubscriptionStatus.CANCELED));

        List<Subscription> rows = subscriptionRepository.findByUserId(userId);

        assertThat(rows).hasSize(2)
                .extracting(Subscription::getProvider)
                .containsExactlyInAnyOrder(SubscriptionProvider.STRIPE, SubscriptionProvider.APP_STORE);
    }

    @Test
    void rejectsASecondRowForTheSameUserAndProvider() {
        Long userId = saveUser("subscription-dup-user-provider-" + System.nanoTime() + "@example.com").getId();
        subscriptionRepository.save(newSubscription(userId, SubscriptionProvider.STRIPE, SubscriptionStatus.ACTIVE));

        assertThatThrownBy(() ->
                subscriptionRepository.save(newSubscription(userId, SubscriptionProvider.STRIPE, SubscriptionStatus.CANCELED)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void rejectsTheSameProviderSubscriptionIdForTwoDifferentUsers() {
        Long firstUserId = saveUser("subscription-dup-psid-a-" + System.nanoTime() + "@example.com").getId();
        Long secondUserId = saveUser("subscription-dup-psid-b-" + System.nanoTime() + "@example.com").getId();

        Subscription first = newSubscription(firstUserId, SubscriptionProvider.STRIPE, SubscriptionStatus.ACTIVE);
        first.setProviderSubscriptionId("sub_shared_123");
        subscriptionRepository.save(first);

        Subscription second = newSubscription(secondUserId, SubscriptionProvider.STRIPE, SubscriptionStatus.ACTIVE);
        second.setProviderSubscriptionId("sub_shared_123");

        assertThatThrownBy(() -> subscriptionRepository.save(second))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void allowsMultipleRowsWithNoProviderSubscriptionId() {
        Long firstUserId = saveUser("subscription-null-psid-a-" + System.nanoTime() + "@example.com").getId();
        Long secondUserId = saveUser("subscription-null-psid-b-" + System.nanoTime() + "@example.com").getId();

        subscriptionRepository.save(newSubscription(firstUserId, SubscriptionProvider.COMP, SubscriptionStatus.ACTIVE));
        subscriptionRepository.save(newSubscription(secondUserId, SubscriptionProvider.COMP, SubscriptionStatus.ACTIVE));

        assertThat(subscriptionRepository.findByUserId(firstUserId)).hasSize(1);
        assertThat(subscriptionRepository.findByUserId(secondUserId)).hasSize(1);
    }

    private Subscription newSubscription(Long userId, SubscriptionProvider provider, SubscriptionStatus status) {
        Subscription subscription = new Subscription();
        subscription.setUser(userRepository.getReferenceById(userId));
        subscription.setProvider(provider);
        subscription.setStatus(status);
        return subscription;
    }

    private User saveUser(String email) {
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }
}
