package com.lifey.mail;

import com.lifey.settings.UserSettingsRepository;
import com.lifey.user.User;
import org.springframework.stereotype.Component;

/**
 * Looks up the recipient's stored language preference. Settings rows are
 * created lazily (see {@code SettingsServiceImpl}), so a user who never opened
 * settings simply has none yet — treated the same as {@code SYSTEM}.
 */
@Component
class MailLanguageResolver {

    private final UserSettingsRepository userSettingsRepository;

    MailLanguageResolver(UserSettingsRepository userSettingsRepository) {
        this.userSettingsRepository = userSettingsRepository;
    }

    MailLanguage resolve(User user) {
        return userSettingsRepository.findByUserId(user.getId())
                .map(settings -> MailLanguage.from(settings.getLanguage()))
                .orElse(MailLanguage.EN);
    }
}
