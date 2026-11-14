import type { rgbToOklch } from "@opencode/theme/tui";

export function negative(color: typeof rgbToOklch): void {
  color("synthetic-wrong-type", 34, 56);
}
