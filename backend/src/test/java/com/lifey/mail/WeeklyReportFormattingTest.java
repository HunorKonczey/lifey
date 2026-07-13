package com.lifey.mail;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class WeeklyReportFormattingTest {

    @Test
    void summarize_noActivity_returnsSingleFallbackLine() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 0, 0, 0, null, null, null, null);

        assertThat(WeeklyReportFormatting.summarize(summary, false, false)).isEqualTo("No activity this week");
        assertThat(WeeklyReportFormatting.summarize(summary, true, false)).isEqualTo("Nincs aktivitás ezen a héten");
    }

    @Test
    void summarize_missedWorkoutOnly_stillCountsAsActivity() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 0, 1, 0, null, null, null, null);

        assertThat(WeeklyReportFormatting.summarize(summary, false, false)).contains("1 missed");
    }

    @Test
    void summarize_noGoalSet_omitsWithinGoalCount() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 3, 0, 5, null, 2150, null, null);

        String text = WeeklyReportFormatting.summarize(summary, false, false);

        assertThat(text).contains("5/7 days logged").contains("avg 2150 kcal");
        assertThat(text).doesNotContain("within goal");
    }

    @Test
    void summarize_withGoal_includesWithinGoalCount() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 3, 0, 5, 4, 2150, null, null);

        String text = WeeklyReportFormatting.summarize(summary, false, false);

        assertThat(text).contains("4 within goal");
    }

    @Test
    void summarize_noWeighIn_saysSo() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 1, 0, 1, null, 2000, null, null);

        assertThat(WeeklyReportFormatting.summarize(summary, false, false)).contains("No weigh-in this week");
    }

    @Test
    void summarize_singleWeighInWithoutBaseline_omitsChange() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 1, 0, 1, null, 2000, 82.4, null);

        String text = WeeklyReportFormatting.summarize(summary, false, false);

        assertThat(text).contains("82.4 kg");
        assertThat(text).doesNotContain("(");
    }

    @Test
    void summarize_weightChange_showsSignedDelta() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 1, 0, 1, null, 2000, 82.0, -0.4);

        assertThat(WeeklyReportFormatting.summarize(summary, false, false)).contains("82.0 kg (-0.4 kg)");
    }

    @Test
    void summarize_html_usesBrSeparators() {
        var summary = new WeeklyTrainerReport.ClientWeekSummary("jane", 1, 0, 0, null, null, null, null);

        assertThat(WeeklyReportFormatting.summarize(summary, false, true)).contains("<br>");
    }

    @Test
    void escapeHtml_escapesReservedCharacters() {
        assertThat(WeeklyReportFormatting.escapeHtml("<script>alert('x') & \"y\"</script>"))
                .isEqualTo("&lt;script&gt;alert(&#39;x&#39;) &amp; &quot;y&quot;&lt;/script&gt;");
    }
}
