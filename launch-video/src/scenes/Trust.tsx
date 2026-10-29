import React from "react";
import { Easing, interpolate, Sequence, useCurrentFrame, useVideoConfig } from "remotion";
import { Backdrop } from "../components/Backdrop";
import { Accent, Caption } from "../components/Caption";
import { AppShot } from "../components/MacWindow";
import { color, font } from "../theme";

/** On-device: the real Models screen beside the promise. */
export const Private: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const points = ["No cloud. No account.", "Works offline once models are in.", "Your voice never leaves your Mac."];
  return (
    <Backdrop>
      <div style={{ display: "flex", alignItems: "center", gap: 90, padding: "0 120px" }}>
        <div style={{ width: 760 }}>
          <Caption align="left" title={<>Everything runs <Accent c={color.green}>on your Mac</Accent>.</>} />
          <div style={{ marginTop: 50, display: "flex", flexDirection: "column", gap: 26 }}>
            {points.map((p, i) => (
              <Sequence key={p} from={(0.8 + i * 0.5) * fps} layout="none">
                <Point text={p} />
              </Sequence>
            ))}
          </div>
        </div>
        <div
          style={{
            translate: interpolate(frame, [0, 0.9 * fps], ["120px 0px", "0px 0px"], {
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
            opacity: interpolate(frame, [0, 0.5 * fps], [0, 1], { extrapolateRight: "clamp" }),
          }}
        >
          <AppShot file="main-models.png" width={820} />
        </div>
      </div>
    </Backdrop>
  );
};

const Point: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  return (
    <div
      style={{
        fontFamily: font,
        fontSize: 44,
        color: color.text,
        display: "flex",
        gap: 20,
        opacity: interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" }),
      }}
    >
      <span style={{ color: color.green }}>✓</span>
      {text}
    </div>
  );
};

/** The pitch in four promises. */
export const Promises: React.FC = () => {
  const { fps } = useVideoConfig();
  const tiles: [string, string][] = [
    ["Asks", "only when it's unsure, and only about those words."],
    ["Never", "swaps a word on a guess. Fixes wait for your OK."],
    ["Stays", "on your Mac. No audio uploaded. Ever."],
    ["Keeps", "every dictation for 24 h. You never lose a word."],
  ];
  return (
    <Backdrop>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 60 }}>
        <Caption title={<>Dictation you can <Accent>trust</Accent>.</>} />
        <div style={{ display: "flex", gap: 34 }}>
          {tiles.map(([big, small], i) => (
            <Sequence key={big} from={(0.5 + i * 0.4) * fps} layout="none">
              <Tile big={big} small={small} />
            </Sequence>
          ))}
        </div>
      </div>
    </Backdrop>
  );
};

const Tile: React.FC<{ big: string; small: string }> = ({ big, small }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <div
      style={{
        width: 400,
        height: 380,
        padding: 40,
        borderRadius: 32,
        background: color.bgSoft,
        border: `1px solid ${color.panelLine}`,
        fontFamily: font,
        opacity: interpolate(frame, [0, 0.4 * fps], [0, 1], { extrapolateRight: "clamp" }),
        translate: interpolate(frame, [0, 0.6 * fps], ["0px 50px", "0px 0px"], {
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
      }}
    >
      <div style={{ fontSize: 84, fontWeight: 800, letterSpacing: -2, color: color.saffron }}>{big}</div>
      <div style={{ marginTop: 18, fontSize: 40, lineHeight: 1.3, color: color.text }}>{small}</div>
    </div>
  );
};
