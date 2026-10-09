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

import java.time.Duration;
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
import static org.mockito.Mockito.verifyNoInteractions;
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

    MutableClock clock;
    FoodNameSearchServiceImpl service;

    @BeforeEach
    void setUp() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(foodRepository.findOwnedBarcodes(eq(USER_ID), any())).thenReturn(Set.of());
        clock = new MutableClock();
        service = serviceWithCap(1000); // the cap is out of the way unless a test is about it
    }

    private FoodNameSearchServiceImpl serviceWithCap(int perMinute) {
        return new FoodNameSearchServiceImpl(client,
                new OpenFoodFactsProperties("http://product", "ua", "http://search", perMinute, HU_TAG),
                foodRepository, currentUserProvider,
                new OffSearchCache(clock), new OffSearchLimiter(perMinute, clock));
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
    void fibreAndSugarAreCarriedOver_andAnImplausibleFigureIsLeftOutNotTheHit() {
        OffSearchItem good = FoodNameSearchServiceImpl.toItem(
                new OffSearchHit("1", "Oats", null, null, 370.0, 13.0, 60.0, 7.0, 10.0, 1.2));
        OffSearchItem typo = FoodNameSearchServiceImpl.toItem(
                new OffSearchHit("2", "Oats", null, null, 370.0, 13.0, 60.0, 7.0, 400.0, -3.0));
        OffSearchItem none = FoodNameSearchServiceImpl.toItem(hit("3", "Oats", null, 370.0, 13.0, 60.0, 7.0));

        assertThat(good.fiberPer100g()).isEqualTo(10.0);
        assertThat(good.sugarPer100g()).isEqualTo(1.2);
        assertThat(typo).isNotNull();
        assertThat(typo.fiberPer100g()).isNull();
        assertThat(typo.sugarPer100g()).isNull();
        assertThat(none.fiberPer100g()).isNull();
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

    // ---- D7: the cache

    @Test
    void theSameSearchTwice_secondIsServedFromTheCache() {
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenReturn(List.of(hit("1", "Tej")));

        OffSearchResponse first = service.search("tej", "hu");
        OffSearchResponse second = service.search("  TEJ ", "hu"); // same sanitised text

        assertThat(second).isEqualTo(first);
        verify(client, times(1)).searchByName(any(), any(), any(), anyInt());
    }

    @Test
    void aFallbackCachesBothPasses_theRepeatCallsOffNoMore() {
        when(client.searchByName("pumpkin", "hu", HU_TAG, 20)).thenReturn(List.of());
        when(client.searchByName("pumpkin", "en", null, 20)).thenReturn(List.of(hit("9", "Pumpkin")));

        OffSearchResponse first = service.search("pumpkin", "hu");
        OffSearchResponse second = service.search("pumpkin", "hu");

        assertThat(first.fellBackToEnglish()).isTrue();
        assertThat(second).isEqualTo(first);
        verify(client, times(2)).searchByName(any(), any(), any(), anyInt()); // one Hungarian, one English — once
    }

    @Test
    void anEmptyPassIsCachedToo() {
        when(client.searchByName("sütőtök", "en", null, 20)).thenReturn(List.of());

        service.search("sütőtök", "en");
        service.search("sütőtök", "en");

        verify(client, times(1)).searchByName(any(), any(), any(), anyInt());
    }

    @Test
    void theSameTextInAnotherLanguageIsNotServedFromTheCache() {
        when(client.searchByName("pasta", "en", null, 20)).thenReturn(List.of(hit("1", "Pasta (en)")));
        when(client.searchByName("pasta", "hu", HU_TAG, 20)).thenReturn(List.of(hit("2", "Pasta (hu)")));

        assertThat(service.search("pasta", "en").items()).extracting(OffSearchItem::name).containsExactly("Pasta (en)");
        assertThat(service.search("pasta", "hu").items()).extracting(OffSearchItem::name).containsExactly("Pasta (hu)");
    }

    @Test
    void aFailureIsNotCached_theNextAttemptCallsOffAgain() {
        when(client.searchByName("tej", "hu", HU_TAG, 20))
                .thenThrow(new OffUnavailableException("timeout"))
                .thenReturn(List.of(hit("1", "Tej")));

        assertThat(service.search("tej", "hu").status()).isEqualTo(OffSearchStatus.UNAVAILABLE);
        OffSearchResponse retry = service.search("tej", "hu");

        assertThat(retry.status()).isEqualTo(OffSearchStatus.OK);
        assertThat(retry.items()).hasSize(1);
        verify(client, times(2)).searchByName(any(), any(), any(), anyInt());
    }

    @Test
    void theCachedResultIsUserIndependent_ownershipIsAppliedPerCaller() {
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenReturn(List.of(hit("1", "Tej")));
        when(foodRepository.findOwnedBarcodes(eq(USER_ID), any())).thenReturn(Set.of("1"));
        when(foodRepository.findOwnedBarcodes(eq(7L), any())).thenReturn(Set.of());

        assertThat(service.search("tej", "hu").items()).isEmpty(); // user 42 owns it
        when(currentUserProvider.getUserId()).thenReturn(7L);
        assertThat(service.search("tej", "hu").items()).hasSize(1); // user 7 does not — from the cache

        verify(client, times(1)).searchByName(any(), any(), any(), anyInt());
    }

    @Test
    void aCachedResultExpiresAfterTheTtl() {
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenReturn(List.of(hit("1", "Tej")));

        service.search("tej", "hu");
        clock.advance(Duration.ofMinutes(11));
        service.search("tej", "hu");

        verify(client, times(2)).searchByName(any(), any(), any(), anyInt());
    }

    // ---- D7: the app-wide cap

    @Test
    void overTheCap_isRateLimitedWithoutCallingOff() {
        FoodNameSearchServiceImpl capped = serviceWithCap(1);
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenReturn(List.of(hit("1", "Tej")));

        assertThat(capped.search("tej", "hu").status()).isEqualTo(OffSearchStatus.OK);
        OffSearchResponse second = capped.search("sajt", "hu"); // a different text: no cache, no permit left

        assertThat(second.status()).isEqualTo(OffSearchStatus.RATE_LIMITED);
        assertThat(second.items()).isEmpty();
        verify(client, times(1)).searchByName(any(), any(), any(), anyInt());
    }

    @Test
    void aCacheHitTakesNoPermit() {
        FoodNameSearchServiceImpl capped = serviceWithCap(1);
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenReturn(List.of(hit("1", "Tej")));

        assertThat(capped.search("tej", "hu").status()).isEqualTo(OffSearchStatus.OK);
        assertThat(capped.search("tej", "hu").status()).isEqualTo(OffSearchStatus.OK);
        assertThat(capped.search("tej", "hu").status()).isEqualTo(OffSearchStatus.OK);
    }

    @Test
    void aHungarianSearchThatFallsBackCostsTwoPermits() {
        FoodNameSearchServiceImpl capped = serviceWithCap(2);
        when(client.searchByName("pumpkin", "hu", HU_TAG, 20)).thenReturn(List.of());
        when(client.searchByName("pumpkin", "en", null, 20)).thenReturn(List.of(hit("9", "Pumpkin")));

        assertThat(capped.search("pumpkin", "hu").fellBackToEnglish()).isTrue();

        assertThat(capped.search("tej", "hu").status()).isEqualTo(OffSearchStatus.RATE_LIMITED);
        verify(client, times(2)).searchByName(any(), any(), any(), anyInt());
    }

    @Test
    void theCapFrees_aMinuteLater() {
        FoodNameSearchServiceImpl capped = serviceWithCap(1);
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenReturn(List.of(hit("1", "Tej")));
        when(client.searchByName("sajt", "hu", HU_TAG, 20)).thenReturn(List.of(hit("2", "Sajt")));
        capped.search("tej", "hu");
        assertThat(capped.search("sajt", "hu").status()).isEqualTo(OffSearchStatus.RATE_LIMITED);

        clock.advance(Duration.ofSeconds(60));

        assertThat(capped.search("sajt", "hu").status()).isEqualTo(OffSearchStatus.OK);
    }

    @Test
    void aCapOfZeroIsAnOffSwitch() {
        FoodNameSearchServiceImpl off = serviceWithCap(0);

        assertThat(off.search("tej", "hu").status()).isEqualTo(OffSearchStatus.RATE_LIMITED);
        verifyNoInteractions(client);
    }

    @Test
    void anUnsearchableQueryCostsNoPermitAndNoCall() {
        FoodNameSearchServiceImpl capped = serviceWithCap(1);
        when(client.searchByName("tej", "hu", HU_TAG, 20)).thenReturn(List.of(hit("1", "Tej")));

        OffSearchResponse nothing = capped.search("  :\"* ", "hu");

        assertThat(nothing.status()).isEqualTo(OffSearchStatus.OK);
        assertThat(nothing.items()).isEmpty();
        assertThat(capped.search("tej", "hu").status()).isEqualTo(OffSearchStatus.OK); // the permit was still there
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
