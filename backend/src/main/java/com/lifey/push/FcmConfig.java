package com.lifey.push;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * Firebase Admin SDK wiring for Android push (docs/30-push-notifications-plan.md,
 * B2 Android follow-up). Both beans — and therefore {@code FcmPushSender} — only
 * exist when {@code lifey.push.fcm.enabled=true}, so local dev/CI never need
 * real Firebase credentials.
 */
@Configuration
@EnableConfigurationProperties(FcmProperties.class)
public class FcmConfig {

    @Bean
    @ConditionalOnProperty(prefix = "lifey.push.fcm", name = "enabled", havingValue = "true")
    FirebaseApp firebaseApp(FcmProperties properties) throws IOException {
        if (!FirebaseApp.getApps().isEmpty()) {
            return FirebaseApp.getInstance();
        }
        try (InputStream credentials = new FileInputStream(properties.credentialsPath())) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(credentials))
                    .build();
            return FirebaseApp.initializeApp(options);
        }
    }

    @Bean
    @ConditionalOnProperty(prefix = "lifey.push.fcm", name = "enabled", havingValue = "true")
    FirebaseMessaging firebaseMessaging(FirebaseApp firebaseApp) {
        return FirebaseMessaging.getInstance(firebaseApp);
    }
}
