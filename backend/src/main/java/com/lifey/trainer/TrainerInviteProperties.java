package com.lifey.trainer;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.trainer-invite.*} (see application.yml). Gates the
 * optional email channel for accepting a trainer invite — the existing
 * mobile polling flow (see {@link com.lifey.trainer.controller.ClientInviteController})
 * works regardless of this setting.
 */
@ConfigurationProperties(prefix = "lifey.trainer-invite")
public record TrainerInviteProperties(
        boolean emailEnabled,
        String publicBaseUrl
) {
}
