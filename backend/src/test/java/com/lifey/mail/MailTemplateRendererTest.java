package com.lifey.mail;

import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class MailTemplateRendererTest {

    private final MailTemplateRenderer renderer = new MailTemplateRenderer();

    @Test
    void renderHtml_substitutesPlaceholdersForEnglishWelcome() {
        String html = renderer.renderHtml("welcome", MailLanguage.EN, Map.of("name", "Jane"));

        assertThat(html)
                .contains("Hi Jane,")
                .contains("Your Lifey account is ready")
                .doesNotContain("{{name}}");
    }

    @Test
    void renderHtml_substitutesPlaceholdersForHungarianPasswordReset() {
        String html = renderer.renderHtml("password_reset", MailLanguage.HU, Map.of("name", "Jane", "code", "123456"));

        assertThat(html)
                .contains("Szia Jane,")
                .contains("123456")
                .doesNotContain("{{code}}");
    }

    @Test
    void renderText_substitutesPlaceholdersInPlainTextVariant() {
        String text = renderer.renderText("password_reset", MailLanguage.EN, Map.of("name", "Jane", "code", "654321"));

        assertThat(text)
                .contains("Hi Jane,")
                .contains("654321")
                .doesNotContain("<");
    }

    @Test
    void renderHtml_weeklyReportOuter_bothLanguages_noLeftoverPlaceholders() {
        Map<String, String> placeholders = Map.of(
                "weekStart", "01 Jun", "weekEnd", "07 Jun", "clientRows", "<tr><td>Jane</td></tr>");

        String en = renderer.renderHtml("weekly_report", MailLanguage.EN, placeholders);
        String hu = renderer.renderHtml("weekly_report", MailLanguage.HU, placeholders);

        assertThat(en).contains("01 Jun").contains("<tr><td>Jane</td></tr>").doesNotContain("{{");
        assertThat(hu).contains("01 Jun").contains("<tr><td>Jane</td></tr>").doesNotContain("{{");
    }

    @Test
    void renderText_weeklyReportOuter_bothLanguages_noLeftoverPlaceholders() {
        Map<String, String> placeholders = Map.of(
                "weekStart", "01 Jun", "weekEnd", "07 Jun", "clientRows", "Jane\nNo activity this week\n");

        String en = renderer.renderText("weekly_report", MailLanguage.EN, placeholders);
        String hu = renderer.renderText("weekly_report", MailLanguage.HU, placeholders);

        assertThat(en).contains("Jane").doesNotContain("{{");
        assertThat(hu).contains("Jane").doesNotContain("{{");
    }

    @Test
    void render_weeklyReportRow_bothFormatsAndLanguages_noLeftoverPlaceholders() {
        Map<String, String> placeholders = Map.of("clientName", "Jane", "summary", "3 completed workouts");

        assertThat(renderer.renderHtml("weekly_report_row", MailLanguage.EN, placeholders))
                .contains("Jane").contains("3 completed workouts").doesNotContain("{{");
        assertThat(renderer.renderHtml("weekly_report_row", MailLanguage.HU, placeholders))
                .contains("Jane").doesNotContain("{{");
        assertThat(renderer.renderText("weekly_report_row", MailLanguage.EN, placeholders))
                .contains("Jane").doesNotContain("{{");
        assertThat(renderer.renderText("weekly_report_row", MailLanguage.HU, placeholders))
                .contains("Jane").doesNotContain("{{");
    }
}
