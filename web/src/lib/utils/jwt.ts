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
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
    // atob yields one char per byte (Latin-1); the payload is UTF-8 JSON, so
    // decode the bytes properly or non-ASCII names ("Új") turn into mojibake.
    const bytes = Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
    return JSON.parse(new TextDecoder().decode(bytes)) as JwtPayload;
  } catch {
    return null;
  }
}
