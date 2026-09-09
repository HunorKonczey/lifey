package com.lifey.billing.controller;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.billing.dto.EntitlementResponse;
import com.lifey.billing.dto.EntitlementSource;
import com.lifey.billing.dto.EntitlementTier;
import com.lifey.billing.exception.InvalidReceiptException;
import com.lifey.billing.exception.SubscriptionAlreadyLinkedException;
import com.lifey.billing.service.StoreBillingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Controller wiring + {@code GlobalExceptionHandler} status mapping (64 §6.1:
 * {@code 200 EntitlementResponse | 409 SUBSCRIPTION_ALREADY_LINKED | 422
 * INVALID_RECEIPT}). The crypto/business-rule cases themselves are covered by
 * {@code StoreBillingServiceImplTest}; this is only the HTTP layer.
 */
@WebMvcTest(StorePurchaseController.class)
class StorePurchaseControllerTest {

    private static final Long USER_ID = 1L;

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    StoreBillingService storeBillingService;

    @MockitoBean
    CurrentUserProvider currentUserProvider;

    @BeforeEach
    void setUp() {
        when(currentUserProvider.getUserId()).thenReturn(USER_ID);
    }

    @Test
    void validPurchase_returns200WithTheFreshEntitlement() throws Exception {
        EntitlementResponse response = new EntitlementResponse(EntitlementTier.PRO, EntitlementSource.APP_STORE,
                false, null, null, null, null, Instant.parse("2026-06-15T09:00:00Z"),
                Instant.parse("2026-06-15T09:00:00Z"), false);
        when(storeBillingService.verifyPurchase(any(), any())).thenReturn(response);

        mockMvc.perform(post("/api/v1/billing/store-purchase")
                        .contentType("application/json")
                        .content("{\"platform\":\"IOS\",\"productId\":\"pro.monthly\",\"purchaseToken\":\"a.b.c\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tier").value("PRO"))
                .andExpect(jsonPath("$.source").value("APP_STORE"));
    }

    @Test
    void invalidReceipt_returns422() throws Exception {
        when(storeBillingService.verifyPurchase(any(), any()))
                .thenThrow(new InvalidReceiptException("bad signature", new RuntimeException()));

        mockMvc.perform(post("/api/v1/billing/store-purchase")
                        .contentType("application/json")
                        .content("{\"platform\":\"IOS\",\"productId\":\"pro.monthly\",\"purchaseToken\":\"tampered\"}"))
                .andExpect(status().isUnprocessableContent());
    }

    @Test
    void alreadyLinkedToAnotherAccount_returns409() throws Exception {
        when(storeBillingService.verifyPurchase(any(), any()))
                .thenThrow(new SubscriptionAlreadyLinkedException("already linked"));

        mockMvc.perform(post("/api/v1/billing/store-purchase")
                        .contentType("application/json")
                        .content("{\"platform\":\"IOS\",\"productId\":\"pro.monthly\",\"purchaseToken\":\"a.b.c\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    void blankPurchaseToken_isRejectedWith400_beforeReachingTheService() throws Exception {
        mockMvc.perform(post("/api/v1/billing/store-purchase")
                        .contentType("application/json")
                        .content("{\"platform\":\"IOS\",\"productId\":\"pro.monthly\",\"purchaseToken\":\"\"}"))
                .andExpect(status().isBadRequest());
    }
}
