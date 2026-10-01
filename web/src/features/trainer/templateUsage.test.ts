import { describe, expect, it } from "vitest";
import { templateTags, templateTotals, templateUsers } from "./templateUsage";
import type { TrainerClientResponse } from "./types";
import type { ExerciseResponse } from "@/features/workouts/types";

const client = (id: number, first: string | null, email = `c${id}@x.hu`) =>
  ({ clientId: id, clientEmail: email, clientFirstName: first, clientLastName: first ? "Teszt" : null }) as TrainerClientResponse;
const exercise = (id: number, category: string | null) => ({ id, name: `E${id}`, category }) as ExerciseResponse;

describe("templateUsers", () => {
  it("keeps the clients with the template, in client order", () => {
    const users = templateUsers([3, 1], [client(1, "Anna"), client(2, "Béla"), client(3, null, "gabor.t@x.hu")]);
    expect(users.map((u) => u.clientId)).toEqual([1, 3]);
    expect(users[0].name).toBe("Anna Teszt");
  });
  it("is empty without assignments or loaded data", () => {
    expect(templateUsers(undefined, [client(1, "Anna")])).toEqual([]);
    expect(templateUsers([9], [client(1, "Anna")])).toEqual([]);
  });
});

describe("templateTags", () => {
  const all = [exercise(1, "QUADS"), exercise(2, "GLUTES"), exercise(3, "ABS"), exercise(4, "CARDIO"), exercise(5, null)];
  it("lists distinct muscle groups in order, at most two", () => {
    expect(templateTags({ exercises: [{ exerciseId: 2, targetSets: 3 }, { exerciseId: 1, targetSets: 3 }, { exerciseId: 3, targetSets: 3 }] }, all)).toEqual(["GLUTES", "QUADS"]);
  });
  it("falls back to cardio when nothing more specific is there, and to nothing without categories", () => {
    expect(templateTags({ exercises: [{ exerciseId: 4, targetSets: 1 }] }, all)).toEqual(["CARDIO"]);
    expect(templateTags({ exercises: [{ exerciseId: 5, targetSets: 1 }] }, all)).toEqual([]);
  });
});

describe("templateTotals", () => {
  it("sums sets and estimates 8 minutes an exercise, rounded to 5", () => {
    expect(templateTotals([{ targetSets: 3 }, { targetSets: 4 }, { targetSets: 4 }])).toEqual({ exercises: 3, sets: 11, minutes: 25 });
    expect(templateTotals([])).toEqual({ exercises: 0, sets: 0, minutes: 0 });
  });
});
