package com.lifey.common.exception;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The catch-all {@code Exception} handler used to answer every Spring MVC failure — a wrong HTTP method,
 * an unsupported media type, a missing parameter, `?before=abc` — with a 500 "unexpected error" and a
 * stack trace in the log. Those are the caller's mistakes and must say so.
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
    void missingRequiredParameter_is400() throws Exception {
        mockMvc.perform(get("/probe/needs-param"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void unparseableParameter_is400() throws Exception {
        mockMvc.perform(get("/probe/number").param("before", "abc"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Invalid value for parameter 'before'"));
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

        @GetMapping("/probe/number")
        String number(@RequestParam Long before) {
            return String.valueOf(before);
        }

        @GetMapping("/probe/boom")
        String boom() {
            throw new IllegalStateException("boom");
        }
    }
}
