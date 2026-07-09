package com.lifey.auth;

import com.lifey.common.image.ImageReencoder;
import com.lifey.user.AvatarSource;
import com.lifey.user.UserAvatar;
import com.lifey.user.UserAvatarRepository;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.web.client.RestClient;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.time.Instant;
import java.util.regex.Pattern;

/**
 * Imports a user's Google account picture into {@code user_avatars} the first
 * time they log in with Google — but only ever fills an empty slot: an
 * existing avatar (uploaded, or imported on a previous login) is never
 * overwritten here, so an explicit upload always wins. Runs async and after
 * commit so a slow/unreachable image host can never delay the login response,
 * and any failure here must never surface to the caller — see docs/22-profile-picture-plan.md.
 */
@Component
@RequiredArgsConstructor
class GoogleAvatarImportListener {

    private static final Logger log = LoggerFactory.getLogger(GoogleAvatarImportListener.class);

    /**
     * Google's avatar CDN host (and subdomains) — the only host this listener will
     * ever fetch from, even though the URL originates from a signature-verified ID
     * token rather than raw user input.
     */
    private static final String ALLOWED_HOST_SUFFIX = "googleusercontent.com";
    private static final Pattern SIZE_SUFFIX = Pattern.compile("=s\\d+-c$");
    private static final String LARGE_SIZE_SUFFIX = "=s512-c";
    private static final int MAX_BYTES = 5 * 1024 * 1024;
    private static final int AVATAR_SIZE = 512;

    private final UserAvatarRepository userAvatarRepository;
    private final UserRepository userRepository;
    private final RestClient googleAvatarRestClient;

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onGoogleAvatarCandidate(GoogleAvatarCandidateEvent event) {
        try {
            if (userAvatarRepository.existsByUserId(event.userId())) {
                return;
            }
            String downloadUrl = resolveDownloadUrl(event.pictureUrl());
            if (downloadUrl == null) {
                log.warn("Skipping Google avatar import for user {}: untrusted picture URL", event.userId());
                return;
            }

            byte[] raw = download(downloadUrl);
            byte[] jpeg = ImageReencoder.toSquareJpeg(new ByteArrayInputStream(raw), AVATAR_SIZE);

            UserAvatar avatar = new UserAvatar();
            avatar.setUser(userRepository.getReferenceById(event.userId()));
            avatar.setImage(jpeg);
            avatar.setContentType(ImageReencoder.CONTENT_TYPE);
            avatar.setSource(AvatarSource.GOOGLE);
            avatar.setUpdatedAt(Instant.now());
            userAvatarRepository.save(avatar);
        } catch (Exception e) {
            log.warn("Failed to import Google avatar for user {}", event.userId(), e);
        }
    }

    private String resolveDownloadUrl(String pictureUrl) {
        URI uri;
        try {
            uri = URI.create(pictureUrl);
        } catch (IllegalArgumentException e) {
            return null;
        }
        String host = uri.getHost();
        boolean trusted = "https".equalsIgnoreCase(uri.getScheme()) && host != null
                && (host.equals(ALLOWED_HOST_SUFFIX) || host.endsWith("." + ALLOWED_HOST_SUFFIX));
        if (!trusted) {
            return null;
        }
        return SIZE_SUFFIX.matcher(pictureUrl).replaceFirst("") + LARGE_SIZE_SUFFIX;
    }

    private byte[] download(String url) {
        return googleAvatarRestClient.get()
                .uri(URI.create(url))
                .exchange((_, response) -> {
                    if (!response.getStatusCode().is2xxSuccessful()) {
                        throw new IOException("Unexpected status downloading avatar: " + response.getStatusCode());
                    }
                    return readLimited(response.getBody());
                });
    }

    private byte[] readLimited(InputStream input) throws IOException {
        byte[] bytes = input.readNBytes(MAX_BYTES + 1);
        if (bytes.length > MAX_BYTES) {
            throw new IOException("Avatar download exceeded the maximum allowed size");
        }
        return bytes;
    }
}
