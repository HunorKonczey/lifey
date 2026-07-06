package com.lifey.superadmin.exception;

/** A super admin tried to grant/revoke a role on their own account. */
public class CannotModifySelfException extends RuntimeException {

    public CannotModifySelfException(String message) {
        super(message);
    }
}
