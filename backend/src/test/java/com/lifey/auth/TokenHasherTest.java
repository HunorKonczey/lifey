package com.lifey.auth;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class TokenHasherTest {

    @Test
    void generateOpaqueToken_producesDistinctValues() {
        String first = TokenHasher.generateOpaqueToken();
        String second = TokenHasher.generateOpaqueToken();

        assertThat(first).isNotEqualTo(second);
        assertThat(first).isNotBlank();
    }

    @Test
    void hash_isDeterministicForTheSameInput() {
        String token = TokenHasher.generateOpaqueToken();

        assertThat(TokenHasher.hash(token)).isEqualTo(TokenHasher.hash(token));
    }

    @Test
    void hash_differsForDifferentInputs() {
        String tokenA = TokenHasher.generateOpaqueToken();
        String tokenB = TokenHasher.generateOpaqueToken();

        assertThat(TokenHasher.hash(tokenA)).isNotEqualTo(TokenHasher.hash(tokenB));
    }

    @Test
    void hash_neverContainsTheRawTokenValue() {
        String token = TokenHasher.generateOpaqueToken();

        assertThat(TokenHasher.hash(token)).doesNotContain(token);
    }
}
