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
import { ToastSection } from "./sections/ToastSection";
import { TableSection } from "./sections/TableSection";
import { ProgressSection } from "./sections/ProgressSection";
import { StatesSection } from "./sections/StatesSection";
import { BarChartSection } from "./sections/BarChartSection";
import { LineChartSection } from "./sections/LineChartSection";
import { ShellSection } from "./sections/ShellSection";
import { DateStepperSection } from "./sections/DateStepperSection";
import { MobileShellSection } from "./sections/MobileShellSection";
import { ShortcutsSection } from "./sections/ShortcutsSection";
import { PageGridSection } from "./sections/PageGridSection";
import { CalorieHeroSection } from "./sections/CalorieHeroSection";
import { RecommendedWorkoutSection } from "./sections/RecommendedWorkoutSection";
import { DashboardTilesSection } from "./sections/DashboardTilesSection";
import { WeekCaloriesSection } from "./sections/WeekCaloriesSection";

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
  { id: "toast", title: "Toast", Component: ToastSection },
  { id: "table", title: "Data table", Component: TableSection },
  { id: "progress", title: "Progress", Component: ProgressSection },
  { id: "states", title: "States", Component: StatesSection },
  { id: "bar-chart", title: "Bar chart", Component: BarChartSection },
  { id: "line-chart", title: "Line chart", Component: LineChartSection },
  { id: "shell", title: "Sidebar & account menu", Component: ShellSection },
  { id: "date-stepper", title: "Date stepper", Component: DateStepperSection },
  { id: "mobile-shell", title: "Mobile shell (bottom nav)", Component: MobileShellSection },
  { id: "page-grid", title: "Page grid", Component: PageGridSection },
  { id: "calorie-hero", title: "Calorie hero", Component: CalorieHeroSection },
  { id: "recommended-workout", title: "Recommended workout", Component: RecommendedWorkoutSection },
  { id: "dashboard-tiles", title: "Dashboard tiles", Component: DashboardTilesSection },
  { id: "week-calories", title: "Week calories", Component: WeekCaloriesSection },
  { id: "shortcuts", title: "Keyboard shortcuts", Component: ShortcutsSection },
  { id: "formatting", title: "Formatting", Component: FormattingSection },
];
