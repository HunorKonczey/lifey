import { ColorSection } from "./sections/ColorSection";
import { TypeSection } from "./sections/TypeSection";
import { TokensSection } from "./sections/TokensSection";
import { MotionSection } from "./sections/MotionSection";
import { IconsSection } from "./sections/IconsSection";
import { FormattingSection } from "./sections/FormattingSection";
import { CardsSection } from "./sections/CardsSection";
import { ChipsAvatarsSection } from "./sections/ChipsAvatarsSection";
import { ControlsSection } from "./sections/ControlsSection";
import { FieldsSection } from "./sections/FieldsSection";
import { DatePickerSection } from "./sections/DatePickerSection";
import { MenuSection } from "./sections/MenuSection";
import { OverlaysSection } from "./sections/OverlaysSection";
import { DrawerSection } from "./sections/DrawerSection";

export interface GallerySection {
  id: string;
  title: string;
  Component: React.ComponentType;
}

/** The gallery page (`/dev/design`, D-W0.12) renders these in order. Each
 *  later W0 step (fields, overlays, table, charts…) adds its own entry here
 *  rather than growing one of the existing sections. */
export const GALLERY_SECTIONS: GallerySection[] = [
  { id: "color", title: "Colour", Component: ColorSection },
  { id: "type", title: "Type", Component: TypeSection },
  { id: "tokens", title: "Radius, spacing, elevation", Component: TokensSection },
  { id: "motion", title: "Motion", Component: MotionSection },
  { id: "icons", title: "Icons", Component: IconsSection },
  { id: "cards", title: "Cards & labels", Component: CardsSection },
  { id: "chips-avatars", title: "Chips & avatars", Component: ChipsAvatarsSection },
  { id: "controls", title: "Controls", Component: ControlsSection },
  { id: "fields", title: "Fields", Component: FieldsSection },
  { id: "date-picker", title: "Date picker", Component: DatePickerSection },
  { id: "menu", title: "Popover & menu", Component: MenuSection },
  { id: "overlays", title: "Modal & confirm", Component: OverlaysSection },
  { id: "drawer", title: "Drawer", Component: DrawerSection },
  { id: "formatting", title: "Formatting", Component: FormattingSection },
];
