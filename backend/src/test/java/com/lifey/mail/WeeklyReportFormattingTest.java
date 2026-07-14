package com.lifey.mail;

import org.junit.jupiter.api.Test;
import org.springframework.context.support.ResourceBundleMessageSource;

import static org.assertj.core.api.Assertions.assertThat;

public class WeeklyReportFormattingTest {

    private final WeeklyReportFormatting formatting = new WeeklyReportFormatting(new MailMessages(testMessageSource()));

    @Test
    void summarize_noActivity_returnsSingleFallbackLine() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 0, 0, 0, null, null, null, null);

        assertThat(formatting.summarize(summary, MailLanguage.EN, false)).isEqualTo("No activity this week");
        assertThat(formatting.summarize(summary, MailLanguage.HU, false)).isEqualTo("Nincs aktivitás ezen a héten");
    }

    @Test
    void summarize_missedWorkoutOnly_stillCountsAsActivity() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 0, 1, 0, null, null, null, null);

        assertThat(formatting.summarize(summary, MailLanguage.EN, false)).contains("1 missed");
    }

    @Test
    void summarize_noGoalSet_omitsWithinGoalCount() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 3, 0, 5, null, 2150, null, null);

        String text = formatting.summarize(summary, MailLanguage.EN, false);

        assertThat(text).contains("5/7 days logged").contains("avg 2150 kcal").doesNotContain("within goal");
    }

    @Test
    void summarize_withGoal_includesWithinGoalCount() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 3, 0, 5, 4, 2150, null, null);

        String text = formatting.summarize(summary, MailLanguage.EN, false);

        assertThat(text).contains("4 within goal");
    }

    @Test
    void summarize_noWeighIn_saysSo() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 1, 0, 1, null, 2000, null, null);

        assertThat(formatting.summarize(summary, MailLanguage.EN, false)).contains("No weigh-in this week");
    }

    @Test
    void summarize_singleWeighInWithoutBaseline_omitsChange() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 1, 0, 1, null, 2000, 82.4, null);

        String text = formatting.summarize(summary, MailLanguage.EN, false);

        assertThat(text).contains("82.4 kg").doesNotContain("(");
    }

    @Test
    void summarize_weightChange_showsSignedDelta() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 1, 0, 1, null, 2000, 82.0, -0.4);

        assertThat(formatting.summarize(summary, MailLanguage.EN, false)).contains("82.0 kg (-0.4 kg)");
    }

    @Test
    void summarize_html_usesBrSeparators() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 1, 0, 0, null, null, null, null);

        assertThat(formatting.summarize(summary, MailLanguage.EN, true)).contains("<br>");
    }

    @Test
    void summarize_largeCalorieCount_notGroupedByLocale() {
        // Regression guard: MessageSource/MessageFormat applies locale-sensitive
        // number grouping (e.g. "2,150") to raw Number arguments — args must go
        // in as Strings so the figure matches what's stored, ungrouped.
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 3, 0, 5, null, 12345, null, null);

        assertThat(formatting.summarize(summary, MailLanguage.EN, false)).contains("avg 12345 kcal");
    }

    @Test
    void escapeHtml_escapesReservedCharacters() {
        assertThat(WeeklyReportFormatting.escapeHtml("<script>alert('x') & \"y\"</script>"))
                .isEqualTo("&lt;script&gt;alert(&#39;x&#39;) &amp; &quot;y&quot;&lt;/script&gt;");
    }

    public static ResourceBundleMessageSource testMessageSource() {
        ResourceBundleMessageSource messageSource = new ResourceBundleMessageSource();
        messageSource.setBasename("i18n/mail");
        messageSource.setDefaultEncoding("UTF-8");
        messageSource.setUseCodeAsDefaultMessage(false);
        messageSource.setFallbackToSystemLocale(false);
        return messageSource;
    }
}
