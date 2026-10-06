package com.lifey.nutrition.openfoodfacts.client;

import com.lifey.nutrition.openfoodfacts.OffSearchHit;
import com.lifey.nutrition.openfoodfacts.exception.OffRateLimitedException;
import com.lifey.nutrition.openfoodfacts.exception.OffUnavailableException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.test.web.client.RequestMatcher;
import org.springframework.test.web.client.response.MockRestResponseCreators;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;
import org.springframework.web.util.UriUtils;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.queryParam;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.http.HttpMethod.GET;

/** The name-search half of {@link OpenFoodFactsClientImpl} (docs/84), against a stubbed search-a-licious. */
class OpenFoodFactsClientImplTest {

    private static final String HU_TAG = "en:hungary";

    private MockRestServiceServer server;
    private OpenFoodFactsClientImpl client;

    @BeforeEach
    void setUp() {
        RestClient.Builder searchBuilder = RestClient.builder().baseUrl("http://search.test");
        server = MockRestServiceServer.bindTo(searchBuilder).build();
        client = new OpenFoodFactsClientImpl(RestClient.create("http://product.test"), searchBuilder.build());
    }

    /** A query parameter as OFF receives it, decoded: the request must be percent-encoded, the text readable. */
    private static RequestMatcher decodedParam(String name, String expected) {
        return request -> {
            String raw = UriComponentsBuilder.fromUri(request.getURI()).build().getQueryParams().getFirst(name);
            assertThat(raw).as(name + " is percent-encoded, no raw quotes or spaces").doesNotContain("\"", " ", ":");
            assertThat(UriUtils.decode(raw, StandardCharsets.UTF_8)).isEqualTo(expected);
        };
    }

    private static final String TWO_HITS = """
            {"hits":[
              {"code":"4056489827702","product_name":"Csirkemell","product_name_hu":"Csirkemell szeletek",
               "product_name_en":"Chicken breast","brands":["Pikok"," Pikok","Aldi"],
               "nutriments":{"energy-kcal_100g":110,"proteins_100g":14,"carbohydrates_100g":2.4,"fat_100g":4.9}},
              {"code":"5999033874557","product_name":null,"brands":null,"nutriments":null,"unknown_field":1}
            ],"count":2}
            """;

    @Test
    void mapsHitsAndPicksTheNameOfTheSearchedLanguage() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withSuccess(TWO_HITS, MediaType.APPLICATION_JSON));

        List<OffSearchHit> hu = client.searchByName("csirkemell", "hu", HU_TAG, 20);

        assertThat(hu).hasSize(2);
        OffSearchHit first = hu.get(0);
        assertThat(first.code()).isEqualTo("4056489827702");
        assertThat(first.productName()).isEqualTo("Csirkemell");
        assertThat(first.localizedName()).isEqualTo("Csirkemell szeletek");
        assertThat(first.brands()).isEqualTo("Pikok, Aldi");
        assertThat(first.energyKcalPer100g()).isEqualTo(110.0);
        assertThat(first.proteinsPer100g()).isEqualTo(14.0);
        assertThat(first.carbohydratesPer100g()).isEqualTo(2.4);
        assertThat(first.fatPer100g()).isEqualTo(4.9);
        OffSearchHit bare = hu.get(1);
        assertThat(bare.productName()).isNull();
        assertThat(bare.localizedName()).isNull();
        assertThat(bare.brands()).isNull();
        assertThat(bare.energyKcalPer100g()).isNull();
    }

    @Test
    void englishSearchReadsTheEnglishName() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withSuccess(TWO_HITS, MediaType.APPLICATION_JSON));

        List<OffSearchHit> en = client.searchByName("chicken", "en", null, 20);

        assertThat(en.get(0).localizedName()).isEqualTo("Chicken breast");
    }

    @Test
    void sendsLanguageSizeFieldsAndTheCountryClause() {
        server.expect(requestTo(org.hamcrest.Matchers.startsWith("http://search.test/search?")))
                .andExpect(decodedParam("q", "csirkemell countries_tags:\"en:hungary\""))
                .andExpect(queryParam("langs", "hu"))
                .andExpect(queryParam("page_size", "20"))
                .andExpect(decodedParam("fields", "code,product_name,product_name_hu,product_name_en,brands,nutriments"))
                .andRespond(MockRestResponseCreators.withSuccess("{\"hits\":[]}", MediaType.APPLICATION_JSON));

        client.searchByName("Csirkemell", "hu", HU_TAG, 20);

        server.verify();
    }

    @Test
    void noCountryTagMeansNoClause() {
        server.expect(decodedParam("q", "snickers"))
                .andExpect(queryParam("langs", "en"))
                .andRespond(MockRestResponseCreators.withSuccess("{\"hits\":[]}", MediaType.APPLICATION_JSON));

        client.searchByName("snickers", "en", null, 20);

        server.verify();
    }

    @Test
    void aLanguageOtherThanHuOrEnSearchesEnglish() {
        server.expect(queryParam("langs", "en"))
                .andRespond(MockRestResponseCreators.withSuccess("{\"hits\":[]}", MediaType.APPLICATION_JSON));

        client.searchByName("käse", "de", null, 20);

        server.verify();
    }

    @Test
    void typedTextCanNotReplaceOrDropTheCountryClause() {
        server.expect(decodedParam("q", "x countries tags en fr countries_tags:\"en:hungary\""))
                .andRespond(MockRestResponseCreators.withSuccess("{\"hits\":[]}", MediaType.APPLICATION_JSON));

        client.searchByName("x countries_tags:\"en:fr\"", "hu", HU_TAG, 20);

        server.verify();
    }

    @Test
    void limitIsClampedToOneToFifty() {
        server.expect(queryParam("page_size", "50"))
                .andRespond(MockRestResponseCreators.withSuccess("{\"hits\":[]}", MediaType.APPLICATION_JSON));
        server.expect(queryParam("page_size", "1"))
                .andRespond(MockRestResponseCreators.withSuccess("{\"hits\":[]}", MediaType.APPLICATION_JSON));

        client.searchByName("tej", "en", null, 500);
        client.searchByName("tej", "en", null, 0);

        server.verify();
    }

    @Test
    void nothingSearchableDoesNotCallOff() {
        assertThat(client.searchByName("  :\"* ", "hu", HU_TAG, 20)).isEmpty();
        assertThat(client.searchByName(null, "hu", HU_TAG, 20)).isEmpty();

        server.verify(); // no expectation was set: any request would have failed already
    }

    @Test
    void anEmptyAnswerIsAnEmptyListNotAnError() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withSuccess("{\"hits\":[]}", MediaType.APPLICATION_JSON));
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withSuccess("{}", MediaType.APPLICATION_JSON));

        assertThat(client.searchByName("sütőtök", "hu", HU_TAG, 20)).isEmpty();
        assertThat(client.searchByName("sütőtök", "hu", HU_TAG, 20)).isEmpty();
    }

    @Test
    void hitsWithoutABarcodeAreSkipped() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withSuccess(
                "{\"hits\":[{\"product_name\":\"No code\"},{\"code\":\"  \"},{\"code\":\" 123 \",\"product_name\":\"Ok\"}]}",
                MediaType.APPLICATION_JSON));

        List<OffSearchHit> hits = client.searchByName("ok", "en", null, 20);

        assertThat(hits).extracting(OffSearchHit::code).containsExactly("123");
    }

    @Test
    void status429IsRateLimited() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withStatus(HttpStatus.TOO_MANY_REQUESTS));

        assertThatThrownBy(() -> client.searchByName("tej", "hu", HU_TAG, 20))
                .isInstanceOf(OffRateLimitedException.class)
                .hasMessageContaining("429");
    }

    @Test
    void status503IsRateLimitedToo() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withStatus(HttpStatus.SERVICE_UNAVAILABLE));

        assertThatThrownBy(() -> client.searchByName("tej", "hu", HU_TAG, 20))
                .isInstanceOf(OffRateLimitedException.class)
                .hasMessageContaining("503");
    }

    @Test
    void otherServerErrorsAreUnavailable() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withServerError());

        assertThatThrownBy(() -> client.searchByName("tej", "hu", HU_TAG, 20))
                .isInstanceOf(OffUnavailableException.class)
                .hasMessageContaining("500");
    }

    @Test
    void clientErrorsAreUnavailableToo() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withStatus(HttpStatus.BAD_REQUEST));

        assertThatThrownBy(() -> client.searchByName("tej", "hu", HU_TAG, 20))
                .isInstanceOf(OffUnavailableException.class);
    }

    @Test
    void aTimeoutOrConnectionFailureIsUnavailable() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withException(new IOException("Read timed out")));

        assertThatThrownBy(() -> client.searchByName("tej", "hu", HU_TAG, 20))
                .isInstanceOf(OffUnavailableException.class)
                .hasCauseInstanceOf(RuntimeException.class);
    }

    @Test
    void anUnreadableBodyIsUnavailable() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withSuccess("<html>nope</html>", MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.searchByName("tej", "hu", HU_TAG, 20))
                .isInstanceOf(OffUnavailableException.class);
    }
}
