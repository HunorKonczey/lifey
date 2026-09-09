package com.lifey.billing.repository;

import com.lifey.billing.entity.ProcessedBillingEvent;
import com.lifey.billing.entity.SubscriptionProvider;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.dao.DataIntegrityViolationException;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Repository slice for {@link ProcessedBillingEvent} — the idempotency ledger
 * (docs/landing_page/64-billing-backend-plan.md §5.4) must reject a duplicate
 * (provider, eventId) insert.
 */
@SpringBootTest
@Testcontainers
class ProcessedBillingEventRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    ProcessedBillingEventRepository repository;

    @Test
    void savesAndReadsBackAnEvent() {
        String eventId = "evt_" + System.nanoTime();
        ProcessedBillingEvent event = newEvent(SubscriptionProvider.STRIPE, eventId);

        Long id = repository.save(event).getId();

        assertThat(repository.findById(id)).isPresent();
        assertThat(repository.existsByProviderAndEventId(SubscriptionProvider.STRIPE, eventId)).isTrue();
    }

    @Test
    void rejectsADuplicateProviderAndEventId() {
        String eventId = "evt_dup_" + System.nanoTime();
        repository.save(newEvent(SubscriptionProvider.STRIPE, eventId));

        assertThatThrownBy(() -> repository.save(newEvent(SubscriptionProvider.STRIPE, eventId)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void allowsTheSameEventIdUnderADifferentProvider() {
        String eventId = "evt_shared_" + System.nanoTime();
        repository.save(newEvent(SubscriptionProvider.STRIPE, eventId));

        assertThat(repository.existsByProviderAndEventId(SubscriptionProvider.PLAY_STORE, eventId)).isFalse();
    }

    private ProcessedBillingEvent newEvent(SubscriptionProvider provider, String eventId) {
        ProcessedBillingEvent event = new ProcessedBillingEvent();
        event.setProvider(provider);
        event.setEventId(eventId);
        event.setEventType("test.event");
        return event;
    }
}
