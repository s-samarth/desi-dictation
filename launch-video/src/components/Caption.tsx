import React from "react";
import { Easing, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { color, font } from "../theme";

/** A scene's headline (and optional line under it), rising in after `delay` seconds. */
export const Caption: React.FC<{
  title: React.ReactNode;
  sub?: React.ReactNode;
  delay?: number;
  align?: "center" | "left";
  style?: React.CSSProperties;
}> = ({ title, sub, delay = 0, align = "center", style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const start = delay * fps;
  return (
    <div style={{ fontFamily: font, textAlign: align, color: color.text, ...style }}>
      <div
        style={{
          fontSize: 84,
          fontWeight: 800,
          letterSpacing: -2,
          lineHeight: 1.08,
          opacity: interpolate(frame, [start, start + 0.5 * fps], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [start, start + 0.7 * fps], ["0px 40px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        {title}
      </div>
      {sub ? (
        <div
          style={{
            marginTop: 22,
            fontSize: 44,
            fontWeight: 400,
            color: color.dim,
            lineHeight: 1.3,
            opacity: interpolate(frame, [start + 0.4 * fps, start + 0.9 * fps], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          {sub}
        </div>
      ) : null}
    </div>
  );
};

/** A word in an accent colour. */
export const Accent: React.FC<{ c?: string; children: React.ReactNode }> = ({ c = color.saffron, children }) => (
  <span style={{ color: c }}>{children}</span>
);
