import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadDevanagari } from "@remotion/google-fonts/NotoSansDevanagari";

// Inter for everything; Noto Sans Devanagari picks up हिन्दी glyphs Inter lacks.
const inter = loadInter("normal", { weights: ["400", "600", "800"], subsets: ["latin"] });
const deva = loadDevanagari("normal", { weights: ["400", "600"], subsets: ["devanagari"] });

export const font = `${inter.fontFamily}, ${deva.fontFamily}, sans-serif`;

// The app icon's tricolor mic, on the app's dark UI.
export const color = {
  bg: "#0b0f1a",
  bgSoft: "#141a2a",
  panel: "#1f1f22",
  panelLine: "rgba(255,255,255,0.10)",
  text: "#f5f5f7",
  dim: "#9aa0ab",
  saffron: "#ff9933",
  green: "#22a95a",
  blue: "#3b82f6",
  purple: "#a855f7",
  red: "#ff453a",
};

export const FPS = 30;
export const WIDTH = 1920;
export const HEIGHT = 1080;
