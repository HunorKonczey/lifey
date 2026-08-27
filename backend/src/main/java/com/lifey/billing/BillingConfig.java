package com.lifey.billing;

import com.apple.itunes.storekit.verification.SignedDataVerifier;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.io.IOException;
import java.io.InputStream;
import java.util.Set;

@Configuration
@EnableConfigurationProperties({BillingProperties.class, StripeProperties.class, AppleProperties.class, GoogleProperties.class})
class BillingConfig {

    /**
     * Safe to build eagerly, unlike {@code AppStoreServerAPIClient} (§6.1's App
     * Store Server API confirmation step) — this only needs the bundle id,
     * environment and Apple's own public root certificate, never a secret, so
     * an unconfigured {@code bundleId} just means every real transaction fails
     * closed rather than the application failing to start.
     */
    @Bean
    SignedDataVerifier signedDataVerifier(AppleProperties appleProperties) throws IOException {
        InputStream rootCertificate = new ClassPathResource("apple/AppleRootCA-G3.cer").getInputStream();
        return new SignedDataVerifier(Set.of(rootCertificate), appleProperties.bundleId(), appleProperties.appAppleId(),
                appleProperties.environment(), false);
    }
}
