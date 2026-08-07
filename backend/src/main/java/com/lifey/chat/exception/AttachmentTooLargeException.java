package com.lifey.chat.exception;

/**
 * Thrown when an image upload is over {@code lifey.chat.attachment-max-bytes} (413).
 *
 * <p>Distinct from the servlet container's own multipart limit: that one is a
 * blunt memory guard shared with avatar and recipe uploads, while this is the
 * chat's own, smaller budget — and it produces an error the client can name.
 */
public class AttachmentTooLargeException extends RuntimeException {

    public AttachmentTooLargeException(String message) {
        super(message);
    }
}
