import { describe, expect, it, vi } from "vitest";
import { disambiguatedName, ensureOwnFood, offFoodRequest, type FoodWriter } from "./offSave";
import type { FoodRequest, FoodResponse, OffSearchItem } from "./types";

const item: OffSearchItem = {
  barcode: "4056489827702",
  name: "Csirkemell",
  brand: "Pikok",
  caloriesPer100g: 110,
  proteinPer100g: 14,
  carbsPer100g: 2.4,
  fatPer100g: 4.9,
};

const conflict = () => Object.assign(new Error("409"), { status: 409 });
const serverError = () => Object.assign(new Error("500"), { status: 500 });

const saved = (id: number, body: FoodRequest): FoodResponse => ({
  id,
  name: body.name,
  caloriesPer100g: body.caloriesPer100g,
  proteinPer100g: body.proteinPer100g,
  carbsPer100g: body.carbsPer100g,
  fatPer100g: body.fatPer100g,
  barcode: body.barcode ?? null,
  hidden: body.hidden,
});

function writer(creates: Array<"ok" | "conflict" | "error">, existing: FoodResponse[] = []) {
  const queue = [...creates];
  const create = vi.fn(async (body: FoodRequest) => {
    const next = queue.shift() ?? "ok";
    if (next === "conflict") throw conflict();
    if (next === "error") throw serverError();
    return saved(1, body);
  });
  const list = vi.fn(async () => existing);
  const api: FoodWriter = { create, list };
  return { api, create, list };
}

describe("offFoodRequest", () => {
  it("carries fibre and sugar when OpenFoodFacts has them, and leaves them out - not as 0 - when it has not (LIF-145)", () => {
    expect(offFoodRequest({ ...item, fiberPer100g: 8.5, sugarPer100g: 0 })).toMatchObject({ fiberPer100g: 8.5, sugarPer100g: 0 });
    const none = offFoodRequest({ ...item, fiberPer100g: null, sugarPer100g: undefined });
    expect(none).not.toHaveProperty("fiberPer100g");
    expect(none).not.toHaveProperty("sugarPer100g");
  });

  it("is a visible food with the per-100 g values and the barcode", () => {
    expect(offFoodRequest(item)).toEqual({
      name: "Csirkemell",
      caloriesPer100g: 110,
      proteinPer100g: 14,
      carbsPer100g: 2.4,
      fatPer100g: 4.9,
      barcode: "4056489827702",
      hidden: false,
    });
  });

  it("makes a missing carbs or fat 0 and trims the name", () => {
    const r = offFoodRequest({ ...item, name: "  Rántott csirkemell ", carbsPer100g: null, fatPer100g: null });

    expect(r.name).toBe("Rántott csirkemell");
    expect(r.carbsPer100g).toBe(0);
    expect(r.fatPer100g).toBe(0);
  });

  it("can leave the barcode out", () => {
    expect(offFoodRequest(item, "X", false).barcode).toBeNull();
  });
});

describe("disambiguatedName", () => {
  it("adds the brand, or OpenFoodFacts without one", () => {
    expect(disambiguatedName(item)).toBe("Csirkemell (Pikok)");
    expect(disambiguatedName({ ...item, brand: null })).toBe("Csirkemell (OpenFoodFacts)");
    expect(disambiguatedName({ ...item, brand: "  " })).toBe("Csirkemell (OpenFoodFacts)");
  });
});

describe("ensureOwnFood", () => {
  it("creates the food once when nothing is in the way", async () => {
    const { api, create, list } = writer(["ok"]);

    const food = await ensureOwnFood(item, api);

    expect(food.name).toBe("Csirkemell");
    expect(create).toHaveBeenCalledTimes(1);
    expect(create.mock.calls[0][0].barcode).toBe("4056489827702");
    expect(list).not.toHaveBeenCalled();
  });

  it("on a 409 uses the food the user already has for that barcode — no second create", async () => {
    const mine = saved(77, { ...offFoodRequest(item), name: "My chicken" });
    const { api, create } = writer(["conflict"], [saved(5, offFoodRequest({ ...item, barcode: "other" })), mine]);

    const food = await ensureOwnFood(item, api);

    expect(food.id).toBe(77);
    expect(create).toHaveBeenCalledTimes(1);
  });

  it("on a 409 caused by the NAME, creates it as 'Name (Brand)' with the barcode", async () => {
    const { api, create } = writer(["conflict", "ok"], [saved(5, offFoodRequest({ ...item, barcode: "other" }))]);

    const food = await ensureOwnFood(item, api);

    expect(create).toHaveBeenCalledTimes(2);
    expect(create.mock.calls[1][0].name).toBe("Csirkemell (Pikok)");
    expect(create.mock.calls[1][0].barcode).toBe("4056489827702");
    expect(food.name).toBe("Csirkemell (Pikok)");
  });

  it("when the barcode is still held (a deleted food), saves it without the barcode", async () => {
    const { api, create } = writer(["conflict", "conflict", "ok"]);

    const food = await ensureOwnFood(item, api);

    expect(create).toHaveBeenCalledTimes(3);
    expect(create.mock.calls[2][0].name).toBe("Csirkemell (Pikok)");
    expect(create.mock.calls[2][0].barcode).toBeNull();
    expect(food.barcode).toBeNull();
  });

  it("throws a third 409 instead of looping", async () => {
    const { api, create } = writer(["conflict", "conflict", "conflict"]);

    await expect(ensureOwnFood(item, api)).rejects.toMatchObject({ status: 409 });
    expect(create).toHaveBeenCalledTimes(3);
  });

  it("throws anything that is not a 409 at once, without retrying under another name", async () => {
    const first = writer(["error"]);
    await expect(ensureOwnFood(item, first.api)).rejects.toMatchObject({ status: 500 });
    expect(first.create).toHaveBeenCalledTimes(1);
    expect(first.list).not.toHaveBeenCalled();

    const second = writer(["conflict", "error"]);
    await expect(ensureOwnFood(item, second.api)).rejects.toMatchObject({ status: 500 });
    expect(second.create).toHaveBeenCalledTimes(2);
  });

  it("throws a failed network call as it is", async () => {
    const api: FoodWriter = { create: vi.fn(async () => { throw new TypeError("Failed to fetch"); }), list: vi.fn() };

    await expect(ensureOwnFood(item, api)).rejects.toThrow("Failed to fetch");
  });
});
