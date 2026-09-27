"use client";

import { useState } from "react";
import { Button } from "../../Button";
import { IconButton } from "../../IconButton";
import { SegmentedControl } from "../../SegmentedControl";
import { Tabs } from "../../Tabs";
import { Switch } from "../../Switch";
import { Checkbox } from "../../Checkbox";
import { ChoiceTileGroup } from "../../ChoiceTile";

/** D-W0.7/D-W0.18 — buttons, icon buttons + tooltip, segmented control,
 *  tabs, switch, checkbox, choice tiles, and the focus ring (Tab through
 *  this section to see it). */
export function ControlsSection() {
  const [segment, setSegment] = useState<"week" | "month" | "year">("week");
  const [tab, setTab] = useState<"overview" | "nutrition" | "workouts">("overview");
  const [on, setOn] = useState(true);
  const [checked, setChecked] = useState(false);
  const [goal, setGoal] = useState<"lose" | "maintain" | "gain">("lose");

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h3 className="type-section mb-2">Buttons</h3>
        <div className="flex flex-wrap items-center gap-3">
          <Button variant="primary">Primary</Button>
          <Button variant="secondary">Secondary</Button>
          <Button variant="tonal">Tonal</Button>
          <Button variant="ghost">Ghost</Button>
          <Button variant="danger">Danger</Button>
          <Button disabled>Disabled</Button>
        </div>
      </div>

      <div>
        <h3 className="type-section mb-2">Icon buttons (hover/focus for the tooltip)</h3>
        <div className="flex items-center gap-3">
          <IconButton icon="close" label="Close" shortcut="Esc" />
          <IconButton icon="edit" label="Edit" />
          <IconButton icon="delete" label="Delete" />
          <IconButton icon="favorite" label="Favourite" fill={1} />
        </div>
      </div>

      <div>
        <h3 className="type-section mb-2">Segmented control (arrow keys)</h3>
        <SegmentedControl
          aria-label="Period"
          value={segment}
          onChange={setSegment}
          options={[
            { value: "week", label: "Week" },
            { value: "month", label: "Month" },
            { value: "year", label: "Year" },
          ]}
        />
      </div>

      <div>
        <h3 className="type-section mb-2">Tabs (underline)</h3>
        <Tabs
          aria-label="Client detail"
          value={tab}
          onChange={setTab}
          items={[
            { value: "overview", label: "Overview" },
            { value: "nutrition", label: "Nutrition" },
            { value: "workouts", label: "Workouts" },
          ]}
        />
      </div>

      <div>
        <h3 className="type-section mb-2">Switch &amp; checkbox</h3>
        <div className="flex items-center gap-6">
          <Switch checked={on} onChange={setOn} label="Weekly report" />
          <Checkbox checked={checked} onChange={setChecked} label="I agree" />
        </div>
      </div>

      <div>
        <h3 className="type-section mb-2">Choice tiles (arrow keys + Space)</h3>
        <ChoiceTileGroup
          aria-label="Goal"
          value={goal}
          onChange={setGoal}
          className="max-w-md"
          options={[
            { value: "lose", label: "Lose weight", icon: "trending_down" },
            { value: "maintain", label: "Maintain", icon: "balance" },
            { value: "gain", label: "Gain muscle", icon: "trending_up" },
          ]}
        />
      </div>
    </div>
  );
}
