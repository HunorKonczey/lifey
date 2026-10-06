package com.lifey.nutrition.food.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.food.dto.OffSearchItem;
import com.lifey.nutrition.food.dto.OffSearchResponse;
import com.lifey.nutrition.food.dto.OffSearchStatus;
import com.lifey.nutrition.openfoodfacts.OffSearchHit;
import com.lifey.nutrition.openfoodfacts.OpenFoodFactsProperties;
import com.lifey.nutrition.openfoodfacts.client.OpenFoodFactsClient;
import com.lifey.nutrition.openfoodfacts.exception.OffRateLimitedException;
import com.lifey.nutrition.openfoodfacts.exception.OffUnavailableException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;

/** docs/84 D4 (language-first, English backoff, errors never fall back) and D6 (the filter). */
@ExtendWith(MockitoExtension.class)
class FoodNameSearchServiceImplTest {

    private static final Long USER_ID = 42L;
    private static final String HU_TAG = "en:hungary";

    @Mock
    OpenFoodFactsClient client;

    @Mock
    FoodRepository foodRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    FoodNameSearchServiceImpl service;

    @BeforeEach
    void setUp() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(foodRepository.findOwnedBarcodes(eq(USER_ID), any())).thenReturn(Set.of());
        service = new FoodNameSearchServiceImpl(client,
                new OpenFoodFactsProperties("http://product", "ua", "http://search", 8, HU_TAG),
                foodRepository, currentUserProvider);
    }

    private static OffSearchHit hit(String code, String name) {
        return new OffSearchHit(code, name, null, "Brand", 110.0, 14.0, 2.4, 4.9);
    }

    private static OffSearchHit hit(String code, String name, String localized, Double kcal, Double protein, Double carbs, Double fat) {
        return new OffSearchHit(code, name, localized, null, kcal, protein, carbs, fat);
    }

    // ---- D4: the flow

    @Test
    void hungarianHit_oneCallWithTheHungaryTag_noFallback() {
        when(client.searchByName("csirkemell", "hu", HU_TAG, 20)).thenReturn(List.of(hit("1", "Csirkemell"), hit("2", "Csirkemell sonka")));

        OffSearchResponse r = service.search("csirkemell", "hu");

        assertThat(r.status()).isEqualTo(OffSearchStatus.OK);
        assertThat(r.language()).isEqualTo("hu");
        assertThat(r.fellBackToEnglish()).isFalse();
        assertThat(r.items()).extracting(OffSearchItem::barcode).containsExactly("1", "2");
        verify(client, times(1)).searchByName(any(), any(), any(), anyInt());
    }

    @Test
    void hungarianEmpty_fallsBackToEnglishWithoutTheCountryTag() {
        when(client.searchByName("pumpkin", "hu", HU_TAG, 20)).thenReturn(List.of());
        when(client.searchByName("pumpkin", "en", null, 20)).thenReturn(List.of(hit("9", "Pumpkin puree")));

        OffSearchResponse r = service.search("pumpkin", "hu");

        assertThat(r.status()).isEqualTo(OffSearchStatus.OK);
        assertThat(r.language()).isEqualTo("en");
        assertThat(r.fellBackToEnglish()).isTrue();
        assertThat(r.items()).extracting(OffSearchItem::name).containsExactly("Pumpkin puree");
    }

    @Test
    void hungarianHitsAllDroppedByTheFilter_countAsNothingAndFallBack() {
        when(client.searchByName("tojás", "hu", HU_TAG, 20))
                .thenReturn(List.of(hit("1", "Tojás", null, null, 12.0, 1.0, 10.0), hit("2", null)));
        when(client.searchByName("tojás", "en", null, 20)).thenReturn(List.of(hit("3", "Egg")));

        OffSearchResponse r = service.search("tojás", "hu");

        assertThat(r.fellBackToEnglish()).isTrue();
        assertThat(r.items()).extracting(OffSearchItem::barcode).containsExactly("3");
    }

    @Test
    void hungarianResultThatIsAllOwned_isStillHungarian_noFallback() {
        when(client.searchByName("alma", "hu", HU_TAG, 20)).thenReturn(List.of(hit("1", "Alma"), hit("2", "Almás pite")));
        when(foodRepository.findOwnedBarcodes(eq(USER_ID), any())).thenReturn(Set.of("1", "2"));

        OffSearchResponse r = service.search("alma", "hu");

        assertThat(r.status()).isEqualTo(OffSearchStatus.OK);
        assertThat(r.language()).isEqualTo("hu");
        assertThat(r.fellBackToEnglish()).isFalse();
        assertThat(r.items()).isEmpty();
        verify(client, never()).searchByName(any(), eq("en"), any(), anyInt());
    }

    @Test
    void bothLanguagesEmpty_isOkWithNoItems_andNoFallbackNote() {
        when(client.searchByName("sütőtök", "hu", HU_TAG, 20)).thenReturn(List.of());
        when(client.searchByName("sütőtök", "en", null, 20)).thenReturn(List.of());

        OffSearchResponse r = service.search("sütőtök", "hu");

        assertThat(r.status()).isEqualTo(OffSearchStatus.OK);
        assertThat(r.items()).isEmpty();
        assertThat(r.language()).isEqualTo("hu");
        assertThat(r.fellBackToEnglish()).isFalse();
    }

    @Test
    void englishRequest_oneCallNoCountryTag_noFallbackWhenEmpty() {
        when(client.searchByName("snickers", "en", null, 20)).thenReturn(List.of());

        OffSearchResponse r = service.search("snickers", "en");

        assertThat(r.status()).isEqualTo(OffSearchStatus.OK);
        assertThat(r.language()).isEqualTo("en");
        assertThat(r.items()).isEmpty();
        verify(client, times(1)).searchByName(any(), any(), any(), anyInt());
    }

    @Test
    void anyOtherLanguageIsSearchedAsEnglish_andHuIsTrimmedAndCaseInsensitive() {
        when(client.searchByName("käse", "en", null, 20)).thenReturn(List.of(hit("1", "Käse")));
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenReturn(List.of(hit("2", "Tej")));

        assertThat(service.search("käse", "de").language()).isEqualTo("en");
        assertThat(service.search("käse", null).language()).isEqualTo("en");
        assertThat(service.search("tej", " HU ").language()).isEqualTo("hu");
    }

    // ---- D4 step 3: a failed call never turns into the English search

    @Test
    void hungarianTimeout_isUnavailable_andTheEnglishClientIsNeverCalled() {
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenThrow(new OffUnavailableException("timeout"));

        OffSearchResponse r = service.search("tej", "hu");

        assertThat(r.status()).isEqualTo(OffSearchStatus.UNAVAILABLE);
        assertThat(r.items()).isEmpty();
        assertThat(r.language()).isEqualTo("hu");
        assertThat(r.fellBackToEnglish()).isFalse();
        verify(client, times(1)).searchByName(any(), any(), any(), anyInt());
        verifyNoMoreInteractions(client);
    }

    @Test
    void hungarianRateLimited_isRateLimited_andTheEnglishClientIsNeverCalled() {
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenThrow(new OffRateLimitedException("429"));

        OffSearchResponse r = service.search("tej", "hu");

        assertThat(r.status()).isEqualTo(OffSearchStatus.RATE_LIMITED);
        assertThat(r.items()).isEmpty();
        verify(client, times(1)).searchByName(any(), any(), any(), anyInt());
    }

    @Test
    void englishPassFailingAfterAnEmptyHungarianPass_isUnavailable() {
        when(client.searchByName("pumpkin", "hu", HU_TAG, 20)).thenReturn(List.of());
        when(client.searchByName("pumpkin", "en", null, 20)).thenThrow(new OffRateLimitedException("503"));

        OffSearchResponse r = service.search("pumpkin", "hu");

        assertThat(r.status()).isEqualTo(OffSearchStatus.RATE_LIMITED);
        assertThat(r.items()).isEmpty();
        assertThat(r.fellBackToEnglish()).isFalse();
    }

    // ---- D6: the filter

    @Test
    void localizedNameWinsOverTheMainName_blankFallsBack_bothBlankDrops() {
        OffSearchItem localized = FoodNameSearchServiceImpl.toItem(hit("1", "Milk 1,5%", "Magyar Tej 1,5%", 45.0, 3.0, 5.0, 1.5));
        OffSearchItem blankLocalized = FoodNameSearchServiceImpl.toItem(hit("2", "Tej", "  ", 45.0, 3.0, 5.0, 1.5));
        OffSearchItem none = FoodNameSearchServiceImpl.toItem(hit("3", " ", null, 45.0, 3.0, 5.0, 1.5));
        OffSearchItem nullNames = FoodNameSearchServiceImpl.toItem(hit("4", null, null, 45.0, 3.0, 5.0, 1.5));

        assertThat(localized.name()).isEqualTo("Magyar Tej 1,5%");
        assertThat(blankLocalized.name()).isEqualTo("Tej");
        assertThat(none).isNull();
        assertThat(nullNames).isNull();
    }

    @Test
    void theNameIsTrimmed() {
        assertThat(FoodNameSearchServiceImpl.toItem(hit("1", "  Túró Rudi ", null, 400.0, 10.0, 30.0, 25.0)).name()).isEqualTo("Túró Rudi");
    }

    @Test
    void kcalAndProteinAreRequired() {
        assertThat(FoodNameSearchServiceImpl.toItem(hit("1", "X", null, null, 10.0, 1.0, 1.0))).isNull();
        assertThat(FoodNameSearchServiceImpl.toItem(hit("2", "X", null, 100.0, null, 1.0, 1.0))).isNull();
    }

    @Test
    void carbsAndFatMayBeMissing_andAreKeptAsNull() {
        OffSearchItem item = FoodNameSearchServiceImpl.toItem(hit("1", "X", null, 100.0, 10.0, null, null));

        assertThat(item).isNotNull();
        assertThat(item.carbsPer100g()).isNull();
        assertThat(item.fatPer100g()).isNull();
    }

    @Test
    void kcalBounds_900Kept_901AndNegativeDropped() {
        assertThat(FoodNameSearchServiceImpl.toItem(hit("1", "Oil", null, 900.0, 0.0, 0.0, 100.0))).isNotNull();
        assertThat(FoodNameSearchServiceImpl.toItem(hit("2", "Typo", null, 901.0, 0.0, 0.0, 10.0))).isNull();
        assertThat(FoodNameSearchServiceImpl.toItem(hit("3", "Typo", null, 9000.0, 1.0, 1.0, 1.0))).isNull();
        assertThat(FoodNameSearchServiceImpl.toItem(hit("4", "Neg", null, -1.0, 1.0, 1.0, 1.0))).isNull();
        assertThat(FoodNameSearchServiceImpl.toItem(hit("5", "Zero", null, 0.0, 0.0, 0.0, 0.0))).isNotNull();
    }

    @Test
    void gramBounds_100Kept_overOrNegativeDropped_forProteinCarbsAndFat() {
        assertThat(FoodNameSearchServiceImpl.toItem(hit("1", "Salt", null, 0.0, 100.0, 100.0, 100.0))).isNotNull();
        assertThat(FoodNameSearchServiceImpl.toItem(hit("2", "P", null, 100.0, 100.1, 1.0, 1.0))).isNull();
        assertThat(FoodNameSearchServiceImpl.toItem(hit("3", "C", null, 100.0, 1.0, 101.0, 1.0))).isNull();
        assertThat(FoodNameSearchServiceImpl.toItem(hit("4", "F", null, 100.0, 1.0, 1.0, 250.0))).isNull();
        assertThat(FoodNameSearchServiceImpl.toItem(hit("5", "P-", null, 100.0, -0.1, 1.0, 1.0))).isNull();
        assertThat(FoodNameSearchServiceImpl.toItem(hit("6", "F-", null, 100.0, 1.0, 1.0, -0.1))).isNull();
    }

    @Test
    void mapsEveryFieldOfAGoodHit() {
        OffSearchItem item = FoodNameSearchServiceImpl.toItem(new OffSearchHit("4056489827702", "Csirkemell", null, "Pikok, Aldi", 110.0, 14.0, 2.4, 4.9));

        assertThat(item).isEqualTo(new OffSearchItem("4056489827702", "Csirkemell", "Pikok, Aldi", 110.0, 14.0, 2.4, 4.9));
    }

    // ---- dedupe and ownership

    @Test
    void twoHitsWithTheSameBarcode_keepTheFirst_andOrderIsOffs() {
        when(client.searchByName("tej", "hu", HU_TAG, 20))
                .thenReturn(List.of(hit("2", "Second"), hit("1", "First"), hit("2", "Second again")));

        OffSearchResponse r = service.search("tej", "hu");

        assertThat(r.items()).extracting(OffSearchItem::name).containsExactly("Second", "First");
    }

    @Test
    void aBarcodeTheUserAlreadyOwnsIsDropped_andTheLookupIsOneQueryForTheCurrentUser() {
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenReturn(List.of(hit("1", "A"), hit("2", "B"), hit("3", "C")));
        when(foodRepository.findOwnedBarcodes(USER_ID, List.of("1", "2", "3"))).thenReturn(Set.of("2"));

        OffSearchResponse r = service.search("tej", "hu");

        assertThat(r.items()).extracting(OffSearchItem::barcode).containsExactly("1", "3");
        verify(foodRepository, times(1)).findOwnedBarcodes(any(), any());
    }
}
