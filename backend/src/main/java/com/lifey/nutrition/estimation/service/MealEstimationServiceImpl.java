package com.lifey.nutrition.estimation.service;

import com.lifey.ai.AiFeatureGate;
import com.lifey.auth.CurrentUserProvider;
import com.lifey.billing.service.AiUsageCounterService;
import com.lifey.common.image.ImageReencoder;
import com.lifey.nutrition.estimation.client.EstimationConfidence;
import com.lifey.nutrition.estimation.client.MealPhotoAnalyzer;
import com.lifey.nutrition.estimation.client.MealPhotoEstimate;
import com.lifey.nutrition.estimation.dto.EstimatedItemResponse;
import com.lifey.nutrition.estimation.dto.MealEstimateResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.Objects;

/**
 * Gate, then call, then count — in that order and nowhere else
 * (docs/23-ai-calorie-estimation-plan.md "The credit counter already exists").
 *
 * <p>Deliberately not {@code @Transactional}: the model call can take tens of
 * seconds and must not hold a connection, and the usage increment has to
 * commit on its own ({@code AiUsageCounterServiceImpl} opens its own
 * transaction) so nothing after a successful call can roll it back. Every
 * failure — gate, image, model, schema — throws before {@code recordUsage} is
 * reached, so a failed call never burns a credit (64 §3.4).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MealEstimationServiceImpl implements MealEstimationService {

    /**
     * Longest side sent to the model. Bounds token cost (~1.5k input tokens)
     * while keeping enough detail to tell foods apart; smaller photos are sent
     * as they are rather than upscaled.
     */
    static final int MAX_IMAGE_SIDE = 1024;

    /** Nobody eats 3 kg in one item; a larger value is a misread, not a portion. */
    static final double MAX_ITEM_GRAMS = 3000;

    /** Fat is ~9 kcal/g, the densest macro; small headroom for rounding and alcohol. */
    static final double MAX_KCAL_PER_GRAM = 9.5;

    static final int MAX_ITEMS = 20;

    private final AiFeatureGate aiFeatureGate;
    private final MealPhotoAnalyzer analyzer;
    private final AiUsageCounterService aiUsageCounterService;
    private final CurrentUserProvider currentUserProvider;

    @Override
    public MealEstimateResponse estimate(MultipartFile image) {
        Long userId = currentUserProvider.getUserId();
        aiFeatureGate.checkMealEstimation(userId);

        byte[] jpeg = ImageReencoder.boundedJpeg(ImageReencoder.decode(inputStream(image)), MAX_IMAGE_SIDE);
        MealPhotoEstimate estimate = analyzer.analyze(jpeg);

        recordUsage(userId);
        return toResponse(estimate);
    }

    /**
     * The user already has a good answer at this point; losing it over a failed
     * counter write would be worse than one uncounted call.
     */
    private void recordUsage(Long userId) {
        try {
            aiUsageCounterService.recordUsage(userId);
        } catch (RuntimeException e) {
            log.error("Could not record AI usage for user {} after a successful meal estimation", userId, e);
        }
    }

    static MealEstimateResponse toResponse(MealPhotoEstimate estimate) {
        List<EstimatedItemResponse> items = estimate.items() == null ? List.of() : estimate.items().stream()
                .filter(Objects::nonNull)
                .map(MealEstimationServiceImpl::toItem)
                .filter(Objects::nonNull)
                .limit(MAX_ITEMS)
                .toList();
        String notes = estimate.notes() == null || estimate.notes().isBlank() ? null : estimate.notes().strip();
        return new MealEstimateResponse(items, notes);
    }

    /**
     * Clamps what the schema cannot rule out: negative or non-finite numbers,
     * absurd portions, and more calories than the portion could physically hold.
     * An item with no name or no weight can't be logged, so it is dropped.
     */
    private static EstimatedItemResponse toItem(MealPhotoEstimate.Item item) {
        double grams = Math.min(sanitize(item.estimatedGrams()), MAX_ITEM_GRAMS);
        if (item.name() == null || item.name().isBlank() || grams <= 0) {
            return null;
        }
        return new EstimatedItemResponse(
                item.name().strip(),
                round(grams),
                round(Math.min(sanitize(item.calories()), grams * MAX_KCAL_PER_GRAM)),
                round(Math.min(sanitize(item.proteinGrams()), grams)),
                round(Math.min(sanitize(item.carbsGrams()), grams)),
                round(Math.min(sanitize(item.fatGrams()), grams)),
                item.confidence() == null ? EstimationConfidence.LOW : item.confidence());
    }

    private static double sanitize(double value) {
        return Double.isFinite(value) && value > 0 ? value : 0;
    }

    private static double round(double value) {
        return Math.round(value * 10) / 10.0;
    }

    private static InputStream inputStream(MultipartFile file) {
        try {
            return file.getInputStream();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
