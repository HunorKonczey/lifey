package com.lifey.mail;

import java.util.Locale;

/**
 * Pure text composition for the weekly trainer report row (docs/33-weekly-trainer-report-plan.md,
 * B5) — split out of {@code ResendMailService} so the localized-summary and
 * HTML-escaping logic is unit-testable without going through the
 * network-guarded send path.
 */
public final class WeeklyReportFormatting {

    private WeeklyReportFormatting() {
    }

    public static String summarize(WeeklyTrainerReport.ClientWeekSummary c, boolean hungarian, boolean html) {
        String separator = html ? "<br>" : "\n";
        boolean noActivity = c.completedWorkouts() == 0 && c.missedWorkouts() == 0
                && c.daysLogged() == 0 && c.weightKg() == null;
        if (noActivity) {
            return hungarian ? "Nincs aktivitás ezen a héten" : "No activity this week";
        }

        String workoutsLine = hungarian
                ? c.completedWorkouts() + " elvégzett edzés · " + c.missedWorkouts() + " kihagyott"
                : c.completedWorkouts() + " completed workouts · " + c.missedWorkouts() + " missed";

        String nutritionLine;
        if (c.daysLogged() == 0) {
            nutritionLine = hungarian ? "Nem volt naplózott étkezés" : "No meals logged";
        } else if (c.daysWithinGoal() == null) {
            nutritionLine = hungarian
                    ? c.daysLogged() + "/7 nap naplózva · átlag " + c.avgCalories() + " kcal"
                    : c.daysLogged() + "/7 days logged · avg " + c.avgCalories() + " kcal";
        } else {
            nutritionLine = hungarian
                    ? c.daysLogged() + "/7 nap naplózva · " + c.daysWithinGoal() + " célon belül · átlag " + c.avgCalories() + " kcal"
                    : c.daysLogged() + "/7 days logged · " + c.daysWithinGoal() + " within goal · avg " + c.avgCalories() + " kcal";
        }

        String weightLine;
        if (c.weightKg() == null) {
            weightLine = hungarian ? "Nem volt mérés ezen a héten" : "No weigh-in this week";
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
