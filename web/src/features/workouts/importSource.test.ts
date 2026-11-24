import { describe, it, expect } from "vitest";
import { importSourceLabel } from "./importSource";

// docs/integrations/89 G1.9: the source chip on the read-only cardio view.
describe("importSourceLabel", () => {
  it("names the app the health store reported", () => {
    expect(importSourceLabel({ importSource: "HEALTH", importAppName: "Garmin Connect" }, "Health app")).toBe("Garmin Connect");
  });

  it("falls back to the health store when no app was reported", () => {
    expect(importSourceLabel({ importSource: "HEALTH", importAppName: null }, "Health app")).toBe("Health app");
    expect(importSourceLabel({ importSource: "HEALTH", importAppName: "   " }, "Health app")).toBe("Health app");
  });

  it("a Garmin API import without an app name reads Garmin Connect", () => {
    expect(importSourceLabel({ importSource: "GARMIN", importAppName: null }, "Health app")).toBe("Garmin Connect");
  });

  it("a session recorded in Lifey has no chip, even with a watch-paired health record", () => {
    expect(importSourceLabel({ importSource: null, importAppName: null }, "Health app")).toBeNull();
    expect(importSourceLabel({}, "Health app")).toBeNull();
  });
});
