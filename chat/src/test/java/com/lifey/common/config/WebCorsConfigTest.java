package com.lifey.common.config;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class WebCorsConfigTest {

    @Test
    void aSingleOriginIsKept() {
        assertThat(WebCorsConfig.parseOrigins("https://lifey-web.vercel.app"))
                .containsExactly("https://lifey-web.vercel.app");
    }

    @Test
    void spacesAroundTheCommaDoNotBreakTheSecondOrigin() {
        assertThat(WebCorsConfig.parseOrigins("https://a.example, https://b.example ,https://c.example"))
                .containsExactly("https://a.example", "https://b.example", "https://c.example");
    }

    @Test
    void aTrailingSlashIsDroppedBecauseABrowserOriginNeverHasOne() {
        assertThat(WebCorsConfig.parseOrigins("https://a.example/")).containsExactly("https://a.example");
    }

    @Test
    void emptyEntriesAreIgnored() {
        assertThat(WebCorsConfig.parseOrigins("https://a.example,, ,")).isEqualTo(List.of("https://a.example"));
    }
}
