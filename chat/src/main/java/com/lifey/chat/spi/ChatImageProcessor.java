package com.lifey.chat.spi;

import java.awt.image.BufferedImage;
import java.io.InputStream;

/**
 * The shared image pipeline (the same one behind avatars and recipe photos),
 * narrowed to the two operations an attachment upload needs.
 *
 * <p>Deliberately not a single {@code encode(upload)} call: <em>how</em> an
 * attachment is re-encoded — decode once, write a bounded image and a bounded
 * thumbnail, then read the stored bytes back for the true dimensions — is chat
 * reasoning (§18.2), and it stays in the chat. Only the pixel work crosses the
 * boundary. {@link BufferedImage} is a JDK type, so nothing about the other
 * module leaks through here.
 */
public interface ChatImageProcessor {

    /**
     * @throws RuntimeException if the bytes are not a decodable image — which is
     *                          how an unreadable upload fails the whole send
     *                          rather than leaving an empty bubble
     */
    BufferedImage decode(InputStream input);

    /** Re-encodes to JPEG with the longest side capped, aspect preserved. */
    byte[] boundedJpeg(BufferedImage source, int maxSide);

    /** Content type of everything {@link #boundedJpeg} produces. */
    String contentType();
}
