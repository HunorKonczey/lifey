import { describe, it, expect } from "vitest";
import { clientDisplayName } from "./ClientAvatar";

describe("clientDisplayName", () => {
  it("prefers the profile name and keeps its accents", () => {
    expect(clientDisplayName({ clientEmail: "reka.toth@example.com", clientFirstName: "Réka", clientLastName: "Tóth" })).toBe("Réka Tóth");
  });

  it("falls back to a name derived from the email when the profile has none", () => {
    expect(clientDisplayName({ clientEmail: "reka.toth@example.com", clientFirstName: null, clientLastName: null })).toBe("Reka Toth");
  });

  it("uses a lone first or last name as is", () => {
    expect(clientDisplayName({ clientEmail: "x@example.com", clientFirstName: "Anna", clientLastName: "  " })).toBe("Anna");
  });
});
