package com.lifey.billing.exception;

/**
 * A store purchase's signature could not be verified — a tampered or
 * malformed JWS, a bundle id / environment mismatch, or an untrusted
 * certificate chain (64 §6.1).
 */
public class InvalidReceiptException extends RuntimeException {

    public InvalidReceiptException(String message, Throwable cause) {
        super(message, cause);
    }
}
