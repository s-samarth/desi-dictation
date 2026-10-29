import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { color } from "../theme";

/** Dark background with a slow-drifting saffron and green glow. */
export const Backdrop: React.FC<{ children?: React.ReactNode }> = ({ children }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const drift = interpolate(frame, [0, durationInFrames], [0, 1]);
  return (
    <AbsoluteFill
      style={{
        backgroundColor: color.bg,
        backgroundImage: `radial-gradient(circle at ${20 + drift * 10}% ${15 + drift * 5}%, rgba(255,153,51,0.18), transparent 45%),
          radial-gradient(circle at ${85 - drift * 10}% ${90 - drift * 5}%, rgba(34,169,90,0.16), transparent 45%)`,
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      {children}
    </AbsoluteFill>
  );
};
