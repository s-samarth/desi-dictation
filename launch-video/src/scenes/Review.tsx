import React from "react";
import { Easing, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { Backdrop } from "../components/Backdrop";
import { Accent, Caption } from "../components/Caption";
import { AppShot } from "../components/MacWindow";
import { color, font } from "../theme";

// public/screens/review.png is 1360×624 (2x); shown at SHOT px wide under a 56 px title bar.
const SHOT = 1300;
const k = SHOT / 1360;
const box = (x: number, y: number, w: number, h: number) => ({ left: x * k, top: 56 + y * k, width: w * k, height: h * k });

/** Review before paste: unsure words underlined, 1 picks the fix, Enter pastes. */
export const Review: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  // Ring moves from the underlined word to its suggestion, then to Paste.
  const stops = [box(100, 96, 104, 52), box(160, 386, 152, 50), box(1218, 552, 112, 50)];
  const at = (a: number, b: number) =>
    interpolate(t, [2.4, 3.0, 4.6, 5.2], [a, b, b, b], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const ring = t < 4.6
    ? { left: at(stops[0].left, stops[1].left), top: at(stops[0].top, stops[1].top), width: at(stops[0].width, stops[1].width), height: at(stops[0].height, stops[1].height) }
    : {
        left: interpolate(t, [4.6, 5.2], [stops[1].left, stops[2].left], { extrapolateRight: "clamp" }),
        top: interpolate(t, [4.6, 5.2], [stops[1].top, stops[2].top], { extrapolateRight: "clamp" }),
        width: interpolate(t, [4.6, 5.2], [stops[1].width, stops[2].width], { extrapolateRight: "clamp" }),
        height: interpolate(t, [4.6, 5.2], [stops[1].height, stops[2].height], { extrapolateRight: "clamp" }),
      };
  const hint = t < 2.4 ? "Unsure words get underlined" : t < 4.6 ? "Press 1 for the fix" : "Enter pastes";
  return (
    <Backdrop>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 44 }}>
        <Caption
          title={<>Not sure it heard you? <Accent>Check before it pastes.</Accent></>}
          sub="Optional. Nothing is changed unless you say so."
        />
        <div
          style={{
            position: "relative",
            translate: interpolate(frame, [0, 0.8 * fps], ["0px 80px", "0px 0px"], {
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
            opacity: interpolate(frame, [0, 0.5 * fps], [0, 1], { extrapolateRight: "clamp" }),
          }}
        >
          <AppShot file="review.png" width={SHOT} />
          <div
            style={{
              position: "absolute",
              ...ring,
              borderRadius: 14,
              border: `5px solid ${color.saffron}`,
              boxShadow: "0 0 0 9999px rgba(0,0,0,0.25)",
              opacity: interpolate(t, [1.2, 1.6], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            }}
          />
        </div>
        <div style={{ fontFamily: font, fontSize: 44, fontWeight: 600, color: color.text }}>{hint}</div>
      </div>
    </Backdrop>
  );
};
