package com.lifey.nutrition.openfoodfacts.client;

import com.lifey.nutrition.openfoodfacts.OffProduct;
import com.lifey.nutrition.openfoodfacts.exception.OffRateLimitedException;
import com.lifey.nutrition.openfoodfacts.exception.OffUnavailableException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.test.web.client.response.MockRestResponseCreators;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.http.HttpMethod.GET;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;

/**
 * The barcode half of {@link OpenFoodFactsClientImpl}. OpenFoodFacts rationing us or being down used to escape as a
 * raw {@code RestClientException} - a 500 "unexpected error" with a stack trace in the log for a state that is OFF's;
 * it now answers like the name search does: rate-limited versus unavailable.
 */
class OpenFoodFactsClientBarcodeTest {

    private MockRestServiceServer server;
    private OpenFoodFactsClientImpl client;

    @BeforeEach
    void setUp() {
        RestClient.Builder productBuilder = RestClient.builder().baseUrl("http://product.test");
        server = MockRestServiceServer.bindTo(productBuilder).build();
        client = new OpenFoodFactsClientImpl(productBuilder.build(), RestClient.create("http://search.test"));
    }

    @Test
    void aKnownProductIsMapped() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withSuccess("""
                {"status":1,"product":{"product_name":"Tej","brands":"Mizo",
                 "nutriments":{"energy-kcal_100g":46,"proteins_100g":3.4,"carbohydrates_100g":4.8,"fat_100g":1.5}}}
                """, MediaType.APPLICATION_JSON));

        Optional<OffProduct> product = client.findByBarcode("5997234150116");

        assertThat(product).get().extracting(OffProduct::name).isEqualTo("Tej");
    }

    @Test
    void anUnknownProductIsEmpty_forBothTheStatusBodyAndAHard404() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withSuccess("{\"status\":0}", MediaType.APPLICATION_JSON));
        assertThat(client.findByBarcode("1")).isEmpty();

        server.reset();
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withStatus(HttpStatus.NOT_FOUND));
        assertThat(client.findByBarcode("2")).isEmpty();
    }

    @Test
    void status429IsRateLimited() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withStatus(HttpStatus.TOO_MANY_REQUESTS));

        assertThatThrownBy(() -> client.findByBarcode("1")).isInstanceOf(OffRateLimitedException.class);
    }

    @Test
    void status503IsRateLimitedToo() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withStatus(HttpStatus.SERVICE_UNAVAILABLE));

        assertThatThrownBy(() -> client.findByBarcode("1")).isInstanceOf(OffRateLimitedException.class);
    }

    @Test
    void otherServerErrorsAreUnavailable() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withServerError());

        assertThatThrownBy(() -> client.findByBarcode("1")).isInstanceOf(OffUnavailableException.class);
    }

    @Test
    void aTimeoutOrConnectionFailureIsUnavailable() {
        server.expect(method(GET)).andRespond(MockRestResponseCreators.withException(new IOException("Read timed out")));

        assertThatThrownBy(() -> client.findByBarcode("1")).isInstanceOf(OffUnavailableException.class);
    }
}
