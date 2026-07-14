package com.lifey.mail;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.Properties;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Guards the i18n/mail_*.properties files against drifting apart: every mail
 * wording key must exist in both languages, otherwise a missing translation
 * would surface as a runtime exception when {@link MailMessages} resolves it
 * (see {@code MailConfig#mailMessageSource()}, {@code useCodeAsDefaultMessage(false)}).
 */
class MailMessagesKeysConsistencyTest {

    @Test
    void enAndHuBundles_haveTheSameKeySet() {
        Set<String> enKeys = keysOf("i18n/mail_en.properties");
        Set<String> huKeys = keysOf("i18n/mail_hu.properties");

        assertThat(enKeys).containsExactlyInAnyOrderElementsOf(huKeys);
    }

    private static Set<String> keysOf(String classpathResource) {
        Properties properties = new Properties();
        try (var reader = new InputStreamReader(
                MailMessagesKeysConsistencyTest.class.getClassLoader().getResourceAsStream(classpathResource),
                StandardCharsets.UTF_8)) {
            properties.load(reader);
        } catch (IOException e) {
            throw new UncheckedIOException("Missing " + classpathResource, e);
        }
        return properties.stringPropertyNames();
    }
}
