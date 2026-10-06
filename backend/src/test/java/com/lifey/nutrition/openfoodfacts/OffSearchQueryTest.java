package com.lifey.nutrition.openfoodfacts;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class OffSearchQueryTest {

    @Test
    void keepsAccentsAndLowerCases() {
        assertThat(OffSearchQuery.sanitize("Túró Rudi")).isEqualTo("túró rudi");
        assertThat(OffSearchQuery.sanitize("Sütőtök")).isEqualTo("sütőtök");
    }

    @Test
    void dropsLuceneFieldSyntax() {
        assertThat(OffSearchQuery.sanitize("tej:")).isEqualTo("tej");
        assertThat(OffSearchQuery.sanitize("categories_tags:\"en:beverages\" tej")).isEqualTo("categories tags en beverages tej");
    }

    @Test
    void dropsQuotesWildcardsAndBrackets() {
        assertThat(OffSearchQuery.sanitize("\"tej")).isEqualTo("tej");
        assertThat(OffSearchQuery.sanitize("tej*")).isEqualTo("tej");
        assertThat(OffSearchQuery.sanitize("(tej OR sajt) ~2 ^3")).isEqualTo("tej or sajt 2 3");
    }

    @Test
    void lowerCasingDefusesUpperCaseOperators() {
        assertThat(OffSearchQuery.sanitize("a OR")).isEqualTo("a or");
        assertThat(OffSearchQuery.sanitize("tej AND NOT sajt")).isEqualTo("tej and not sajt");
    }

    @Test
    void keepsHyphenAndApostropheInsideAWord() {
        assertThat(OffSearchQuery.sanitize("coca-cola")).isEqualTo("coca-cola");
        assertThat(OffSearchQuery.sanitize("lay's")).isEqualTo("lay's");
    }

    @Test
    void dropsAHyphenThatWouldMeanNot() {
        assertThat(OffSearchQuery.sanitize("-tej")).isEqualTo("tej");
        assertThat(OffSearchQuery.sanitize("tej -sajt")).isEqualTo("tej sajt");
        assertThat(OffSearchQuery.sanitize("tej - sajt")).isEqualTo("tej sajt");
        assertThat(OffSearchQuery.sanitize("tej-")).isEqualTo("tej");
    }

    @Test
    void collapsesAndTrimsSpaces() {
        assertThat(OffSearchQuery.sanitize("   görög    joghurt \t")).isEqualTo("görög joghurt");
    }

    @Test
    void nothingSearchableGivesAnEmptyString() {
        assertThat(OffSearchQuery.sanitize(null)).isEmpty();
        assertThat(OffSearchQuery.sanitize("")).isEmpty();
        assertThat(OffSearchQuery.sanitize("   ")).isEmpty();
        assertThat(OffSearchQuery.sanitize(":\"*()-")).isEmpty();
    }
}
