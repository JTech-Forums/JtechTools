import { apiInitializer } from "discourse/lib/api";

interface PickerScheme {
  id: number;
  name: string;
  colors: unknown;
}

interface PickerTheme {
  color_scheme_id?: number | null;
  dark_color_scheme_id?: number | null;
  only_theme_color_schemes?: boolean;
}

// The parts of core's preferences/interface controller used here
interface InterfacePreferences {
  currentThemeForColorSchemes: PickerTheme | undefined;
  userSelectableColorSchemes: PickerScheme[] | null;
  userSelectableDarkColorSchemes: PickerScheme[] | null;
}

// JTech offers its own palettes only (only_theme_color_schemes), and more
// than one dark one (Dark, Dim), so preferences show a dark-palette picker.
// Everyone starts on "the theme's default" (-1), but for theme-only lists
// core leaves that entry out, and the picker shows "-1". Here the theme's
// default palette stands in for it: it shows as "JTech Dark", and picking it
// still means "follow the theme".
function withDefault(
  schemes: PickerScheme[] | null,
  theme: PickerTheme | undefined,
  defaultId: number | null | undefined
): PickerScheme[] | null {
  if (
    !schemes ||
    !theme?.only_theme_color_schemes ||
    !defaultId ||
    schemes.some((s) => s.id === -1)
  ) {
    return schemes;
  }
  return schemes.map((s) => (s.id === defaultId ? { ...s, id: -1 } : s));
}

export default apiInitializer((api) => {
  api.modifyClass(
    "controller:preferences/interface",
    (Superclass: new (...args: unknown[]) => InterfacePreferences) =>
      class extends Superclass {
        get userSelectableColorSchemes(): PickerScheme[] | null {
          const theme = this.currentThemeForColorSchemes;
          return withDefault(
            super.userSelectableColorSchemes,
            theme,
            theme?.color_scheme_id
          );
        }

        get userSelectableDarkColorSchemes(): PickerScheme[] | null {
          const theme = this.currentThemeForColorSchemes;
          return withDefault(
            super.userSelectableDarkColorSchemes,
            theme,
            theme?.dark_color_scheme_id
          );
        }
      },
    undefined
  );
});
