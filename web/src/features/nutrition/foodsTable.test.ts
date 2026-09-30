import { describe, expect, it } from "vitest";
import { matchesFoodSearch } from "./foodsTable";

describe("matchesFoodSearch", () => {
  it("matches anywhere in the name, ignoring case", () => {
    expect(matchesFoodSearch("Görög joghurt 2%", "JOGH")).toBe(true);
    expect(matchesFoodSearch("Görög joghurt 2%", "zab")).toBe(false);
  });

  it("ignores accents in both the name and the search", () => {
    expect(matchesFoodSearch("Édesburgonya", "edes")).toBe(true);
    expect(matchesFoodSearch("Edesburgonya", "éDes")).toBe(true);
    expect(matchesFoodSearch("Görög joghurt", "gorog")).toBe(true);
  });

  it("needs every word, in any order", () => {
    expect(matchesFoodSearch("Görög joghurt 2%", "joghurt görög")).toBe(true);
    expect(matchesFoodSearch("Görög joghurt 2%", "joghurt tej")).toBe(false);
  });

  it("an empty or blank search matches everything", () => {
    expect(matchesFoodSearch("Alma", "")).toBe(true);
    expect(matchesFoodSearch("Alma", "   ")).toBe(true);
  });
});
