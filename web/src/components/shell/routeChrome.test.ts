import { describe, expect, it } from "vitest";
import { routeChrome } from "./routeChrome";

describe("routeChrome", () => {
  it("resolves a client page's title and date stepper", () => {
    expect(routeChrome("/dashboard")).toEqual({ titleKey: "nav.dashboard", hasDateStepper: true, chrome: "standard" });
    expect(routeChrome("/settings")).toEqual({ titleKey: "nav.settings", hasDateStepper: false, chrome: "standard" });
  });

  it("doesn't let /admin shadow a longer /admin/* prefix", () => {
    expect(routeChrome("/admin").titleKey).toBe("admin.nav.clients");
    expect(routeChrome("/admin/billing").titleKey).toBe("admin.nav.billing");
  });

  it("gives a trainer client detail page the date stepper", () => {
    expect(routeChrome("/admin/clients/42").hasDateStepper).toBe(true);
  });

  it("titles the superadmin pages without a date stepper", () => {
    expect(routeChrome("/superadmin/users")).toEqual({ titleKey: "superadmin.usersTitle", hasDateStepper: false, chrome: "standard" });
    expect(routeChrome("/superadmin/trainer-requests").titleKey).toBe("superadmin.trainerRequestsTitle");
  });

  it("falls back to no title outside the known routes", () => {
    expect(routeChrome("/onboarding")).toEqual({ titleKey: null, hasDateStepper: false, chrome: "standard" });
  });

  it("the live workout logger is focus mode; the workouts page itself is not", () => {
    expect(routeChrome("/workouts/session/42").chrome).toBe("focus");
    expect(routeChrome("/workouts").chrome).toBe("standard");
    expect(routeChrome("/workouts?tab=templates").chrome).toBe("standard");
    expect(routeChrome("/admin/workouts").chrome).toBe("standard");
  });
});
