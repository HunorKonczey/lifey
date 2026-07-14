package com.lifey.mail;

import com.lifey.settings.LanguagePreference;

import java.util.Locale;

/**
 * The two languages templates are actually written in. {@link LanguagePreference#SYSTEM}
 * has no server-resolvable locale, so it (and any missing settings row) falls
 * back to {@link #EN}.
 */
public enum MailLanguage {
    EN,
    HU;

    static MailLanguage from(LanguagePreference preference) {
        if (preference == LanguagePreference.HUNGARIAN) {
            return HU;
        }
        return EN;
    }

    Locale toLocale() {
        return this == HU ? Locale.forLanguageTag("hu") : Locale.ENGLISH;
    }
}
