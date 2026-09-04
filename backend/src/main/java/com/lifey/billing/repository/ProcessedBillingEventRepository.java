package com.lifey.billing.repository;

import com.lifey.billing.entity.ProcessedBillingEvent;
import com.lifey.billing.entity.SubscriptionProvider;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProcessedBillingEventRepository extends JpaRepository<ProcessedBillingEvent, Long> {

    boolean existsByProviderAndEventId(SubscriptionProvider provider, String eventId);
}
