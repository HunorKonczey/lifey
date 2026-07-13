package com.lifey.mail;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.MessageSource;
import org.springframework.stereotype.Component;

/**
 * Looks up mail wording from {@code i18n/mail_en.properties} /
 * {@code mail_hu.properties} (see {@link MailConfig#mailMessageSource()}) so
 * that subjects and body copy live in resource files, not Java string
 * literals — the same key set in both languages.
 */
@Component
public class MailMessages {

    private final MessageSource mailMessageSource;

    public MailMessages(@Qualifier("mailMessageSource") MessageSource mailMessageSource) {
        this.mailMessageSource = mailMessageSource;
    }

    public String get(String key, MailLanguage language, Object... args) {
        return mailMessageSource.getMessage(key, args, language.toLocale());
    }
}
