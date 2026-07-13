package com.lifey.mail;

import org.springframework.stereotype.Component;

import java.util.Locale;

/**
 * Text composition for the weekly trainer report row (docs/33-weekly-trainer-report-plan.md,
 * B5) — split out of {@code ResendMailService} so the localized-summary and
 * HTML-escaping logic is unit-testable without going through the
 * network-guarded send path. Wording itself comes from {@link MailMessages}
 * (i18n/mail_*.properties), not string literals here.
 */
@Component
public class WeeklyReportFormatting {

    private final MailMessages messages;

    public WeeklyReportFormatting(MailMessages messages) {
        this.messages = messages;
    }

    public String summarize(WeeklyTrainerReport.ClientWeekSummary c, MailLanguage language, boolean html) {
        String separator = html ? "<br>" : "\n";
        boolean noActivity = c.completedWorkouts() == 0 && c.missedWorkouts() == 0
                && c.daysLogged() == 0 && c.weightKg() == null;
        if (noActivity) {
            return messages.get("mail.weekly-report.no-activity", language);
        }

        // Numeric args go in as Strings, not Number — MessageFormat applies
        // locale-sensitive grouping (e.g. "2,150") to raw Number arguments,
        // which would alter the figures shown in the email.
        String workoutsLine = messages.get("mail.weekly-report.workouts-line", language,
                String.valueOf(c.completedWorkouts()), String.valueOf(c.missedWorkouts()));

        String nutritionLine;
        if (c.daysLogged() == 0) {
            nutritionLine = messages.get("mail.weekly-report.no-meals", language);
        } else if (c.daysWithinGoal() == null) {
            nutritionLine = messages.get("mail.weekly-report.nutrition-no-goal", language,
                    String.valueOf(c.daysLogged()), String.valueOf(c.avgCalories()));
        } else {
            nutritionLine = messages.get("mail.weekly-report.nutrition-with-goal", language,
                    String.valueOf(c.daysLogged()), String.valueOf(c.daysWithinGoal()), String.valueOf(c.avgCalories()));
        }

        String weightLine;
        if (c.weightKg() == null) {
            weightLine = messages.get("mail.weekly-report.no-weigh-in", language);
        } else if (c.weightChangeKg() == null) {
            weightLine = String.format(Locale.ROOT, "%.1f kg", c.weightKg());
        } else {
            weightLine = String.format(Locale.ROOT, "%.1f kg (%+.1f kg)", c.weightKg(), c.weightChangeKg());
        }

        return workoutsLine + separator + nutritionLine + separator + weightLine;
    }

    public static String escapeHtml(String value) {
        return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }
}
