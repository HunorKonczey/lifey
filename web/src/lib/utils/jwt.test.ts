import { describe, it, expect } from "vitest";
import { decodeJwt } from "./jwt";

// Builds a JWT with the given payload (header.payload.signature, base64url).
function makeJwt(payload: Record<string, unknown>): string {
  const b64 = (o: unknown) =>
    Buffer.from(JSON.stringify(o)).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  return `${b64({ alg: "HS512" })}.${b64(payload)}.signature`;
}

describe("decodeJwt", () => {
  it("decodes user claims from a valid token", () => {
    const token = makeJwt({ sub: "42", email: "a@b.com", roles: ["ROLE_USER"], exp: 1, iat: 0 });
    const claims = decodeJwt(token);
    expect(claims?.sub).toBe("42");
    expect(claims?.email).toBe("a@b.com");
    expect(claims?.roles).toEqual(["ROLE_USER"]);
  });

  it("returns null for malformed tokens", () => {
    expect(decodeJwt("not-a-jwt")).toBeNull();
    expect(decodeJwt("")).toBeNull();
  });
});
