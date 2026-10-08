import { expect, type APIRequestContext } from "@playwright/test";

/**
 * Probes for the parts of the environment that only some backend-dependent specs need (see e2e/README.md). A spec that
 * needs one calls `test.skip(!(await …(request)), "reason")`, so a missing piece shows up as a named skip rather than a
 * confusing failure halfway through the flow.
 */

export const API_BASE = "http://localhost:8080/api/v1";
export const CHAT_BASE = "http://localhost:8081/api/v1";
const CHAT_HEALTH = "http://localhost:8081/actuator/health";

let billingProbe: Promise<boolean> | null = null;

/**
 * True only when the backend runs with `BILLING_ENABLED=true`: a fresh, role-less user then resolves to
 * `source: "NONE"`; with billing off every user gets the open COMP entitlement. Asked once per worker — it registers
 * an account, and the ten billing tests would otherwise register ten.
 */
export function billingIsEnabled(request: APIRequestContext): Promise<boolean> {
  billingProbe ??= (async () => {
    const email = `e2e-billing-probe-${Date.now()}@example.com`;
    const password = "E2eProbe123!";
    const registerRes = await request.post(`${API_BASE}/auth/register`, {
      data: { email, password, firstName: "Probe", lastName: "Test" },
    });
    expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
    const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password } });
    const { accessToken } = await loginRes.json();
    const entRes = await request.get(`${API_BASE}/me/entitlements`, { headers: { Authorization: `Bearer ${accessToken}` } });
    const entitlement: { source: string } = await entRes.json();
    return entitlement.source === "NONE";
  })();
  return billingProbe;
}

/** True when the chat service (its own Spring Boot app since docs/chat/44) answers on :8081. */
export async function chatServiceIsUp(request: APIRequestContext): Promise<boolean> {
  try {
    const res = await request.get(CHAT_HEALTH, { timeout: 3_000 });
    return res.ok();
  } catch {
    return false;
  }
}
