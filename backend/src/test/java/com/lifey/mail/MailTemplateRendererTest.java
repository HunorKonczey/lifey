package com.lifey.mail;

import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class MailTemplateRendererTest {

    private final MailTemplateRenderer renderer = new MailTemplateRenderer();

    @Test
    void renderHtml_substitutesPlaceholdersForEnglishWelcome() {
        String html = renderer.renderHtml("welcome", MailLanguage.EN, Map.of("name", "Jane"));

        assertThat(html).contains("Hi Jane,");
        assertThat(html).contains("Your Lifey account is ready");
        assertThat(html).doesNotContain("{{name}}");
    }

    @Test
    void renderHtml_substitutesPlaceholdersForHungarianPasswordReset() {
        String html = renderer.renderHtml("password_reset", MailLanguage.HU, Map.of("name", "Jane", "code", "123456"));

        assertThat(html).contains("Szia Jane,");
        assertThat(html).contains("123456");
        assertThat(html).doesNotContain("{{code}}");
    }

    @Test
    void renderText_substitutesPlaceholdersInPlainTextVariant() {
        String text = renderer.renderText("password_reset", MailLanguage.EN, Map.of("name", "Jane", "code", "654321"));

        assertThat(text).contains("Hi Jane,");
        assertThat(text).contains("654321");
        assertThat(text).doesNotContain("<");
    }
}
