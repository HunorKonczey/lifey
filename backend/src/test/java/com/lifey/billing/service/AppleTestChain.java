package com.lifey.billing.service;

import org.bouncycastle.asn1.ASN1ObjectIdentifier;
import org.bouncycastle.asn1.DERNull;
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x509.BasicConstraints;
import org.bouncycastle.asn1.x509.Extension;
import org.bouncycastle.cert.X509CertificateHolder;
import org.bouncycastle.cert.X509v3CertificateBuilder;
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter;
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.bouncycastle.operator.ContentSigner;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;

import java.math.BigInteger;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.Security;
import java.security.cert.X509Certificate;
import java.security.spec.ECGenParameterSpec;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.List;

/**
 * Builds a real, self-signed X.509 chain — root CA, WWDR-shaped intermediate,
 * receipt-signer-shaped leaf — so {@code StoreBillingServiceImplTest} can
 * exercise Apple's actual {@code SignedDataVerifier}/{@code ChainVerifier}
 * cryptography end to end without real Apple credentials, which don't exist
 * in this environment.
 *
 * <p>{@code ChainVerifier} requires the x5c array to be exactly 3 certificates
 * and requires the leaf and intermediate to each carry a specific Apple OID
 * ({@code AppleExtensionCertPathChecker}) — both replicated here with dummy
 * (but present) extension values, since only presence is checked, not content.
 *
 * <p>Public so {@code com.lifey.billing.controller.webhook}'s webhook tests
 * (`64` Prompt 10) can reuse the same real cryptography without a second,
 * divergent chain builder.
 */
public final class AppleTestChain {

    private static final ASN1ObjectIdentifier WWDR_INTERMEDIATE_OID = new ASN1ObjectIdentifier("1.2.840.113635.100.6.2.1");
    private static final ASN1ObjectIdentifier RECEIPT_SIGNER_OID = new ASN1ObjectIdentifier("1.2.840.113635.100.6.11.1");

    static {
        Security.addProvider(new BouncyCastleProvider());
    }

    private AppleTestChain() {
    }

    public record Chain(X509Certificate rootCertificate, PrivateKey leafPrivateKey, List<String> x5c) {
    }

    public static Chain generate() throws Exception {
        KeyPair rootKeyPair = generateEcKeyPair();
        KeyPair intermediateKeyPair = generateEcKeyPair();
        KeyPair leafKeyPair = generateEcKeyPair();

        X509Certificate rootCert = buildCertificate(rootKeyPair.getPublic(), "CN=Test Apple Root CA",
                "CN=Test Apple Root CA", rootKeyPair.getPrivate(), true, null);
        X509Certificate intermediateCert = buildCertificate(intermediateKeyPair.getPublic(), "CN=Test WWDR Intermediate",
                "CN=Test Apple Root CA", rootKeyPair.getPrivate(), true, WWDR_INTERMEDIATE_OID);
        X509Certificate leafCert = buildCertificate(leafKeyPair.getPublic(), "CN=Test Receipt Signer",
                "CN=Test WWDR Intermediate", intermediateKeyPair.getPrivate(), false, RECEIPT_SIGNER_OID);

        List<String> x5c = List.of(
                Base64.getEncoder().encodeToString(leafCert.getEncoded()),
                Base64.getEncoder().encodeToString(intermediateCert.getEncoded()),
                Base64.getEncoder().encodeToString(rootCert.getEncoded()));

        return new Chain(rootCert, leafKeyPair.getPrivate(), x5c);
    }

    private static KeyPair generateEcKeyPair() throws Exception {
        KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance("EC");
        keyPairGenerator.initialize(new ECGenParameterSpec("secp256r1"));
        return keyPairGenerator.generateKeyPair();
    }

    // A fixed, wide window rather than "now ± a bit": ChainVerifier validates
    // against the JWS payload's own signedDate (with enableOnlineChecks off), not
    // wall-clock time, so tests are free to pick any signedDate — including ones
    // in the past or future relative to whenever this suite actually runs — as
    // long as it falls inside this range.
    private static final Instant VALID_FROM = Instant.parse("2020-01-01T00:00:00Z");
    private static final Instant VALID_UNTIL = Instant.parse("2035-01-01T00:00:00Z");

    private static X509Certificate buildCertificate(PublicKey subjectKey, String subjectDn, String issuerDn,
                                                      PrivateKey signingKey, boolean isCa,
                                                      ASN1ObjectIdentifier appleExtensionOid) throws Exception {
        X509v3CertificateBuilder builder = new JcaX509v3CertificateBuilder(
                new X500Name(issuerDn),
                BigInteger.valueOf(System.nanoTime()),
                Date.from(VALID_FROM),
                Date.from(VALID_UNTIL),
                new X500Name(subjectDn),
                subjectKey);
        builder.addExtension(Extension.basicConstraints, true, new BasicConstraints(isCa));
        if (appleExtensionOid != null) {
            builder.addExtension(appleExtensionOid, false, DERNull.INSTANCE);
        }
        ContentSigner signer = new JcaContentSignerBuilder("SHA256withECDSA").build(signingKey);
        X509CertificateHolder holder = builder.build(signer);
        return new JcaX509CertificateConverter().getCertificate(holder);
    }
}
