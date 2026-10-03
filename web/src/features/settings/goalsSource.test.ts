import { describe, expect, it } from "vitest";
import { clientGoalsChip, trainerGoalsChip } from "./goalsSource";

const AT = "2026-09-12T08:00:00Z";

describe("clientGoalsChip", () => {
  it("names the trainer when the name is known, and says \"your trainer\" when the account is gone", () => {
    expect(clientGoalsChip({ source: "TRAINER", setAt: AT, setByName: "Bence Edző" })).toEqual({ key: "byTrainerNamed", name: "Bence Edző", at: AT });
    expect(clientGoalsChip({ source: "TRAINER", setAt: AT, setByName: null })).toEqual({ key: "byTrainer", at: AT });
  });
  it("shows nothing for goals the person set themself, for unknown, or while loading", () => {
    expect(clientGoalsChip({ source: "SELF", setAt: AT, setByName: null })).toBeNull();
    expect(clientGoalsChip({ source: "UNKNOWN", setAt: null, setByName: null })).toBeNull();
    expect(clientGoalsChip(undefined)).toBeNull();
  });
  it("never invents a date: a TRAINER source without setAt shows nothing", () => {
    expect(clientGoalsChip({ source: "TRAINER", setAt: null, setByName: "Bence" })).toBeNull();
  });
});

describe("trainerGoalsChip", () => {
  it("tells your own change from another trainer's and from the client's", () => {
    expect(trainerGoalsChip({ source: "TRAINER", setAt: AT, setByYou: true })).toEqual({ key: "byYou", at: AT });
    expect(trainerGoalsChip({ source: "TRAINER", setAt: AT, setByYou: false })).toEqual({ key: "byOtherTrainer", at: AT });
    expect(trainerGoalsChip({ source: "SELF", setAt: AT, setByYou: false })).toEqual({ key: "byClient", at: AT });
  });
  it("shows nothing when it was never recorded", () => {
    expect(trainerGoalsChip({ source: "UNKNOWN", setAt: null, setByYou: false })).toBeNull();
    expect(trainerGoalsChip(undefined)).toBeNull();
  });
});
