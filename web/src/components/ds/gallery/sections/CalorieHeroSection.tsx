"use client";

import { CalorieHeroView } from "@/features/dashboard/components/CalorieHero";

const noop = () => {};

/**
 * The dashboard hero's three states (W1.2) on fixture data: under budget
 * (the canvas' 1 041 / 1 900), over budget, and no calorie goal with one
 * macro goal-less.
 */
export function CalorieHeroSection() {
  return (
    <div className="flex flex-col gap-6">
      <div data-state="remaining">
        <CalorieHeroView
          kcal={1041}
          goalKcal={1900}
          macros={{ protein: { value: 68, goal: 120 }, carbs: { value: 120, goal: 190 }, fat: { value: 32, goal: 65 } }}
          onAdd={noop}
        />
      </div>
      <div data-state="over">
        <CalorieHeroView
          kcal={2112}
          goalKcal={1900}
          macros={{ protein: { value: 135, goal: 120 }, carbs: { value: 240, goal: 190 }, fat: { value: 70, goal: 65 } }}
          onAdd={noop}
        />
      </div>
      <div data-state="no-goal">
        <CalorieHeroView
          kcal={640}
          goalKcal={null}
          macros={{ protein: { value: 41, goal: null }, carbs: { value: 80, goal: null }, fat: { value: 22, goal: null } }}
          onAdd={noop}
          showGoalsHint
        />
      </div>
    </div>
  );
}
