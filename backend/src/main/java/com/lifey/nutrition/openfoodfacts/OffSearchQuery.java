package com.lifey.nutrition.openfoodfacts;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Turns what a user typed into a safe OpenFoodFacts search text (docs/84 D11).
 *
 * <p>search-a-licious parses {@code q} as Lucene query syntax: {@code categories_tags:"en:beverages" tej}
 * is a filter, {@code -tej} excludes, {@code tej*} is a wildcard, an upper-case {@code OR}
 * is an operator. None of that is an error — it silently changes what is searched — so only
 * letters, digits, spaces, apostrophes and hyphens <em>inside</em> a word survive, and the
 * text is lower-cased (Lucene operators are upper-case words). Accents are kept: "túró"
 * must stay "túró".
 */
public final class OffSearchQuery {

    private static final Pattern DISALLOWED = Pattern.compile("[^\\p{L}\\p{N}'’\\- ]");
    // A hyphen not between two letters/digits is a Lucene "NOT" or noise.
    private static final Pattern LOOSE_HYPHEN = Pattern.compile("(?<![\\p{L}\\p{N}])-|-(?![\\p{L}\\p{N}])");
    private static final Pattern SPACES = Pattern.compile("\\s+");

    private OffSearchQuery() {
    }

    /**
     * @return the safe text, possibly empty (nothing searchable was typed); never {@code null}
     */
    public static String sanitize(String raw) {
        if (raw == null) {
            return "";
        }
        String text = raw.toLowerCase(Locale.ROOT);
        text = DISALLOWED.matcher(text).replaceAll(" ");
        text = LOOSE_HYPHEN.matcher(text).replaceAll(" ");
        return SPACES.matcher(text).replaceAll(" ").trim();
    }
}
