import React from "react";
import { useCurrentFrame, useVideoConfig } from "remotion";
import { color, font } from "../theme";

/** The Right ⌥ key, held down between `from` and `to` seconds. */
export const Keycap: React.FC<{ from: number; to: number; style?: React.CSSProperties }> = ({ from, to, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const down = t >= from && t <= to;
  return (
    <div
      style={{
        width: 150,
        height: 130,
        borderRadius: 22,
        background: down ? "#2a2f3d" : "#323848",
        border: `2px solid ${down ? color.saffron : "rgba(255,255,255,0.18)"}`,
        boxShadow: down ? "0 2px 0 #11141c" : "0 10px 0 #11141c",
        translate: down ? "0px 8px" : "0px 0px",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        padding: "16px 20px",
        fontFamily: font,
        color: color.text,
        ...style,
      }}
    >
      <span style={{ fontSize: 44, alignSelf: "flex-end" }}>⌥</span>
      <span style={{ fontSize: 22, color: color.dim }}>option</span>
    </div>
  );
};
