package com.lifey.ai;

import com.lifey.ai.exception.AiCreditsExhaustedException;
import com.lifey.billing.BillingProperties;
import com.lifey.billing.dto.EntitlementResponse;
import com.lifey.billing.dto.EntitlementSource;
import com.lifey.billing.dto.EntitlementTier;
import com.lifey.billing.service.AiUsageCounterService;
import com.lifey.billing.service.EntitlementService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EntitlementAiFeatureGateTest {

    private static final Long USER_ID = 7L;
    private static final BillingProperties BILLING = new BillingProperties(true, 30, 3, 7, 200, 100);

    @Mock
    EntitlementService entitlementService;

    @Mock
    AiUsageCounterService aiUsageCounterService;

    EntitlementAiFeatureGate gate;

    @BeforeEach
    void setUp() {
        gate = new EntitlementAiFeatureGate(entitlementService, aiUsageCounterService, BILLING);
    }

    @Test
    void free_underAllowance_passes() {
        givenTier(EntitlementTier.FREE);
        when(aiUsageCounterService.usedThisMonth(USER_ID)).thenReturn(2);

        assertThatCode(() -> gate.checkMealEstimation(USER_ID)).doesNotThrowAnyException();
    }

    @Test
    void free_atAllowance_throws402() {
        givenTier(EntitlementTier.FREE);
        when(aiUsageCounterService.usedThisMonth(USER_ID)).thenReturn(3);

        assertThatThrownBy(() -> gate.checkMealEstimation(USER_ID))
                .isInstanceOf(AiCreditsExhaustedException.class);
    }

    @Test
    void pro_pastTheFreeAllowance_passes() {
        givenTier(EntitlementTier.PRO);
        when(aiUsageCounterService.usedThisMonth(USER_ID)).thenReturn(99);

        assertThatCode(() -> gate.checkMealEstimation(USER_ID)).doesNotThrowAnyException();
    }

    @Test
    void pro_atFairUseCeiling_throws402() {
        givenTier(EntitlementTier.PRO);
        when(aiUsageCounterService.usedThisMonth(USER_ID)).thenReturn(100);

        assertThatThrownBy(() -> gate.checkMealEstimation(USER_ID))
                .isInstanceOf(AiCreditsExhaustedException.class);
    }

    private void givenTier(EntitlementTier tier) {
        Instant now = Instant.parse("2026-09-22T10:00:00Z");
        when(entitlementService.resolve(USER_ID)).thenReturn(new EntitlementResponse(
                tier, EntitlementSource.NONE, tier == EntitlementTier.FREE, null, null,
                null, null, now, now, false));
    }
}
