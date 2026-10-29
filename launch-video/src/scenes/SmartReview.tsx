import React from "react";
import { Easing, interpolate, Sequence, useCurrentFrame, useVideoConfig } from "remotion";
import { Backdrop } from "../components/Backdrop";
import { Accent, Caption } from "../components/Caption";
import { color, font } from "../theme";

/** "Ask cloud to send the deck to Cavya": the two words it isn't sure of, underlined. */
const UnsureLine: React.FC = () => (
  <span>
    Ask <U>cloud</U> to send the deck to <U>Cavya</U>.
  </span>
);

const U: React.FC<{ children: string }> = ({ children }) => (
  <span style={{ textDecoration: `underline wavy ${color.saffron}`, textUnderlineOffset: 10, textDecorationThickness: 3 }}>
    {children}
  </span>
);

/** One dictation and what the app does with it. */
const Row: React.FC<{ said: React.ReactNode; verdict: string; detail: string; c: string }> = ({ said, verdict, detail, c }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 50,
        fontFamily: font,
        opacity: interpolate(frame, [0, 0.4 * fps], [0, 1], clamp),
        translate: interpolate(frame, [0, 0.6 * fps], ["0px 40px", "0px 0px"], {
          ...clamp,
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
      }}
    >
      <div
        style={{
          width: 900,
          padding: "30px 40px",
          borderRadius: 24,
          background: color.bgSoft,
          border: `1px solid ${color.panelLine}`,
          fontSize: 46,
          color: color.text,
        }}
      >
        {said}
      </div>
      <div style={{ width: 620, opacity: interpolate(frame, [0.8 * fps, 1.2 * fps], [0, 1], clamp) }}>
        <div style={{ fontSize: 46, fontWeight: 800, color: c }}>{verdict}</div>
        <div style={{ marginTop: 8, fontSize: 34, color: color.dim }}>{detail}</div>
      </div>
    </div>
  );
};

/** Review only interrupts when it's unsure, and only shows the unsure words. */
export const SmartReview: React.FC = () => {
  const { fps } = useVideoConfig();
  return (
    <Backdrop>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 70 }}>
        <Caption title={<>A review that only shows up <Accent>when it's unsure</Accent>.</>} />
        <div style={{ display: "flex", flexDirection: "column", gap: 40 }}>
          <Sequence from={0.9 * fps} layout="none">
            <Row
              said="Let's push the launch to Friday."
              verdict="Sure → pasted"
              detail="No pop-up. No extra step."
              c={color.green}
            />
          </Sequence>
          <Sequence from={2.9 * fps} layout="none">
            <Row
              said={<UnsureLine />}
              verdict="Unsure → a quick check"
              detail="Just these 2 words to look at."
              c={color.saffron}
            />
          </Sequence>
        </div>
      </div>
    </Backdrop>
  );
};
