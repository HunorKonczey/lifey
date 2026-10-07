package com.lifey.common.exception;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.core.PropertyReferenceException;
import org.springframework.data.core.PropertyPath;
import org.springframework.data.core.TypeInformation;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The catch-all {@code Exception} handler used to answer every Spring MVC failure with a 500
 * "unexpected error": a wrong HTTP method, a body in an unsupported media type, a sort property that
 * does not exist. Those are the caller's mistakes and must say so (405 / 415 / 400), with the headers
 * (`Allow`) Spring attaches to them.
 */
class FrameworkErrorStatusTest {

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new Probe())
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void wrongHttpMethod_is405WithAllowHeader() throws Exception {
        mockMvc.perform(delete("/probe/read"))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(header().string("Allow", "GET"))
                .andExpect(jsonPath("$.status").value(405));
    }

    @Test
    void unsupportedContentType_is415() throws Exception {
        mockMvc.perform(post("/probe/write").contentType("text/plain").content("hello"))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.status").value(415));
    }

    @Test
    void missingRequiredParameter_isStill400() throws Exception {
        mockMvc.perform(get("/probe/needs-param"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void unknownSortProperty_is400() throws Exception {
        mockMvc.perform(get("/probe/sorted"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Unknown property 'nope'"));
    }

    @Test
    void aRationingFoodDatabase_is429() throws Exception {
        mockMvc.perform(get("/probe/off-limited"))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.message").value("The food database is busy, try again in a moment"));
    }

    @Test
    void anUnreachableFoodDatabase_is503() throws Exception {
        mockMvc.perform(get("/probe/off-down"))
                .andExpect(status().isServiceUnavailable());
    }

    @Test
    void anythingElse_isStill500() throws Exception {
        mockMvc.perform(get("/probe/boom"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.message").value("An unexpected error occurred"));
    }

    @RestController
    static class Probe {

        @GetMapping("/probe/read")
        String read() {
            return "ok";
        }

        @PostMapping(value = "/probe/write", consumes = "application/json")
        String write(@RequestBody String body) {
            return body;
        }

        @GetMapping("/probe/needs-param")
        String needsParam(@RequestParam String q) {
            return q;
        }

        @GetMapping("/probe/sorted")
        String sorted() {
            throw new PropertyReferenceException("nope", TypeInformation.of(String.class), List.<PropertyPath>of());
        }

        @GetMapping("/probe/off-limited")
        String offLimited() {
            throw new com.lifey.nutrition.openfoodfacts.exception.OffRateLimitedException("429");
        }

        @GetMapping("/probe/off-down")
        String offDown() {
            throw new com.lifey.nutrition.openfoodfacts.exception.OffUnavailableException("down");
        }

        @GetMapping("/probe/boom")
        String boom() {
            throw new IllegalStateException("boom");
        }
    }
}
