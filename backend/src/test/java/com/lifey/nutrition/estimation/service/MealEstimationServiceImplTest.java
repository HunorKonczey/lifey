package com.lifey.nutrition.estimation.service;

import com.lifey.ai.AiFeatureGate;
import com.lifey.ai.exception.AiCreditsExhaustedException;
import com.lifey.ai.exception.AiUnavailableException;
import com.lifey.auth.CurrentUserProvider;
import com.lifey.billing.service.AiUsageCounterService;
import com.lifey.common.exception.InvalidImageException;
import com.lifey.nutrition.estimation.client.EstimationConfidence;
import com.lifey.nutrition.estimation.client.MealPhotoAnalyzer;
import com.lifey.nutrition.estimation.client.MealPhotoEstimate;
import com.lifey.nutrition.estimation.dto.EstimatedItemResponse;
import com.lifey.nutrition.estimation.dto.MealEstimateResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MealEstimationServiceImplTest {

    private static final Long USER_ID = 42L;

    @Mock
    AiFeatureGate aiFeatureGate;

    @Mock
    MealPhotoAnalyzer analyzer;

    @Mock
    AiUsageCounterService aiUsageCounterService;

    @Mock
    CurrentUserProvider currentUserProvider;

    MealEstimationServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new MealEstimationServiceImpl(aiFeatureGate, analyzer, aiUsageCounterService, currentUserProvider);
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
    }

    @Test
    void estimate_success_countsOneCreditAndMapsItems() throws IOException {
        when(analyzer.analyze(any())).thenReturn(new MealPhotoEstimate(List.of(
                new MealPhotoEstimate.Item("Grilled chicken breast", 150, 248, 46.5, 0, 5.4,
                        EstimationConfidence.HIGH)),
                "  Sauce not visible.  "));

        MealEstimateResponse response = service.estimate(png(640, 480));

        assertThat(response.items()).containsExactly(new EstimatedItemResponse(
                "Grilled chicken breast", 150, 248, 46.5, 0, 5.4, EstimationConfidence.HIGH));
        assertThat(response.notes()).isEqualTo("Sauce not visible.");
        verify(aiFeatureGate).checkMealEstimation(USER_ID);
        verify(aiUsageCounterService).recordUsage(USER_ID);
    }

    @Test
    void estimate_noFood_returnsEmptyItemsAndNullNotesWhenBlank() throws IOException {
        when(analyzer.analyze(any())).thenReturn(new MealPhotoEstimate(List.of(), " "));

        MealEstimateResponse response = service.estimate(png(64, 64));

        assertThat(response.items()).isEmpty();
        assertThat(response.notes()).isNull();
    }

    @Test
    void estimate_gateRejects_neitherCallsModelNorCounts() throws IOException {
        doThrow(new AiCreditsExhaustedException()).when(aiFeatureGate).checkMealEstimation(USER_ID);

        assertThatThrownBy(() -> service.estimate(png(64, 64))).isInstanceOf(AiCreditsExhaustedException.class);

        verifyNoInteractions(analyzer, aiUsageCounterService);
    }

    @Test
    void estimate_modelFails_doesNotBurnACredit() throws IOException {
        when(analyzer.analyze(any())).thenThrow(new AiUnavailableException("down"));

        assertThatThrownBy(() -> service.estimate(png(64, 64))).isInstanceOf(AiUnavailableException.class);

        verify(aiUsageCounterService, never()).recordUsage(any());
    }

    @Test
    void estimate_invalidImage_doesNotCallModelOrCount() {
        MockMultipartFile garbage = new MockMultipartFile("image", "x.jpg", "image/jpeg", new byte[]{1, 2, 3});

        assertThatThrownBy(() -> service.estimate(garbage)).isInstanceOf(InvalidImageException.class);

        verifyNoInteractions(analyzer, aiUsageCounterService);
    }

    @Test
    void estimate_counterFailure_stillReturnsTheEstimate() throws IOException {
        when(analyzer.analyze(any())).thenReturn(new MealPhotoEstimate(List.of(), ""));
        doThrow(new IllegalStateException("db down")).when(aiUsageCounterService).recordUsage(USER_ID);

        assertThat(service.estimate(png(64, 64)).items()).isEmpty();
    }

    @Test
    void estimate_downscalesLargePhotosAndLeavesSmallOnes() throws IOException {
        when(analyzer.analyze(any())).thenReturn(new MealPhotoEstimate(List.of(), ""));
        ArgumentCaptor<byte[]> sent = ArgumentCaptor.forClass(byte[].class);

        service.estimate(png(4000, 3000));
        service.estimate(png(300, 200));

        verify(analyzer, org.mockito.Mockito.times(2)).analyze(sent.capture());
        assertThat(dimensions(sent.getAllValues().get(0))).containsExactly(1024, 768);
        assertThat(dimensions(sent.getAllValues().get(1))).containsExactly(300, 200);
    }

    @Test
    void toResponse_clampsImplausibleValuesAndDropsUnloggableItems() {
        MealEstimateResponse response = MealEstimationServiceImpl.toResponse(new MealPhotoEstimate(Arrays.asList(
                new MealPhotoEstimate.Item("Pizza", 9000, 99999, -3, Double.NaN, 40.04, null),
                new MealPhotoEstimate.Item("  ", 100, 100, 1, 1, 1, EstimationConfidence.LOW),
                new MealPhotoEstimate.Item("Air", 0, 10, 0, 0, 0, EstimationConfidence.LOW),
                null),
                null));

        assertThat(response.items()).containsExactly(new EstimatedItemResponse(
                "Pizza", 3000, 28500, 0, 0, 40.0, EstimationConfidence.LOW));
        assertThat(response.notes()).isNull();
    }

    private static MockMultipartFile png(int width, int height) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB), "png", out);
        return new MockMultipartFile("image", "meal.png", "image/png", out.toByteArray());
    }

    private static int[] dimensions(byte[] jpeg) throws IOException {
        BufferedImage image = ImageIO.read(new ByteArrayInputStream(jpeg));
        return new int[]{image.getWidth(), image.getHeight()};
    }
}
