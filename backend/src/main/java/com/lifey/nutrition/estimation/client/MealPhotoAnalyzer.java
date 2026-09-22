package com.lifey.nutrition.estimation.client;

/**
 * Asks the model what is on a meal photo — the seam between the estimation
 * service (gating, image handling, clamping, credit counting) and the Claude
 * API call itself.
 */
public interface MealPhotoAnalyzer {

    /**
     * @param jpeg an already decoded, downscaled, metadata-free JPEG
     * @throws com.lifey.ai.exception.AiUnavailableException when the call fails
     * or yields no usable answer
     * @throws com.lifey.ai.exception.AiNotConfiguredException when no API key is set
     */
    MealPhotoEstimate analyze(byte[] jpeg);
}
