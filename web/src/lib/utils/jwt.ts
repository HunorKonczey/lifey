export interface JwtPayload {
  sub: string; // user id
  email: string;
  firstName?: string;
  lastName?: string;
  roles: string[];
  exp: number;
  iat: number;
}

/**
 * Decode a JWT payload without verifying the signature.
 * Verification happens server-side; this is only used to read user claims
 * (id, email, roles) for display since /auth/login returns no user object.
 */
export function decodeJwt(token: string): JwtPayload | null {
  try {
    const payload = token.split(".")[1];
    const decoded = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
    return JSON.parse(decoded) as JwtPayload;
  } catch {
    return null;
  }
}
