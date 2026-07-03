package com.lifey.superadmin.exception;

/** Only ROLE_TRAINER can be granted/revoked via the API — everything else is SQL-only. */
public class RoleNotManageableException extends RuntimeException {

    public RoleNotManageableException(String message) {
        super(message);
    }
}
