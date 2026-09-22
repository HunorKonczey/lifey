package com.lifey.nutrition.estimation;

import com.lifey.ai.exception.AiCreditsExhaustedException;
import com.lifey.ai.exception.AiNotConfiguredException;
import com.lifey.ai.exception.AiUnavailableException;
import com.lifey.nutrition.estimation.client.EstimationConfidence;
import com.lifey.nutrition.estimation.dto.EstimatedItemResponse;
import com.lifey.nutrition.estimation.dto.MealEstimateResponse;
import com.lifey.nutrition.estimation.service.MealEstimationService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(MealEstimationController.class)
class MealEstimationControllerTest {

    private static final MockMultipartFile PHOTO =
            new MockMultipartFile("image", "meal.jpg", "image/jpeg", new byte[]{1, 2, 3});

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    MealEstimationService service;

    @Test
    void estimate_returnsItemsForThePortion() throws Exception {
        when(service.estimate(any())).thenReturn(new MealEstimateResponse(List.of(
                new EstimatedItemResponse("Grilled chicken breast", 150, 248, 46.5, 0, 5.4,
                        EstimationConfidence.HIGH)),
                null));

        mockMvc.perform(multipart("/api/v1/meals/estimate").file(PHOTO))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].name").value("Grilled chicken breast"))
                .andExpect(jsonPath("$.items[0].estimatedGrams").value(150.0))
                .andExpect(jsonPath("$.items[0].calories").value(248.0))
                .andExpect(jsonPath("$.items[0].confidence").value("HIGH"));
    }

    @Test
    void estimate_missingImagePart_returns400() throws Exception {
        mockMvc.perform(multipart("/api/v1/meals/estimate"))
                .andExpect(status().isBadRequest());

        verify(service, never()).estimate(any());
    }

    @Test
    void estimate_creditsExhausted_returns402WithCode() throws Exception {
        when(service.estimate(any())).thenThrow(new AiCreditsExhaustedException());

        mockMvc.perform(multipart("/api/v1/meals/estimate").file(PHOTO))
                .andExpect(status().isPaymentRequired())
                .andExpect(jsonPath("$.message").value("AI_CREDITS_EXHAUSTED"));
    }

    @Test
    void estimate_modelFailure_returns502WithoutUpstreamDetail() throws Exception {
        when(service.estimate(any())).thenThrow(new AiUnavailableException("Claude API rejected the request"));

        mockMvc.perform(multipart("/api/v1/meals/estimate").file(PHOTO))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.message").value("AI_UNAVAILABLE"));
    }

    @Test
    void estimate_notConfigured_returns503() throws Exception {
        when(service.estimate(any())).thenThrow(new AiNotConfiguredException());

        mockMvc.perform(multipart("/api/v1/meals/estimate").file(PHOTO))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.message").value("AI_NOT_CONFIGURED"));
    }
}
