import React from "react";
import { Img, staticFile } from "remotion";
import { color, font } from "../theme";

/** A plain macOS window: traffic lights, a title, and whatever goes inside. */
export const MacWindow: React.FC<{
  title?: string;
  width: number;
  height?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ title, width, height, children, style }) => (
  <div
    style={{
      width,
      height,
      borderRadius: 22,
      overflow: "hidden",
      background: color.panel,
      border: `1px solid ${color.panelLine}`,
      boxShadow: "0 40px 120px rgba(0,0,0,0.55)",
      fontFamily: font,
      display: "flex",
      flexDirection: "column",
      ...style,
    }}
  >
    <div style={{ height: 56, display: "flex", alignItems: "center", padding: "0 22px", gap: 10, flexShrink: 0 }}>
      {["#ff5f57", "#febc2e", "#28c840"].map((c) => (
        <div key={c} style={{ width: 16, height: 16, borderRadius: 8, background: c }} />
      ))}
      {title ? (
        <div style={{ flex: 1, textAlign: "center", marginRight: 78, fontSize: 22, fontWeight: 600, color: color.dim }}>
          {title}
        </div>
      ) : null}
    </div>
    <div style={{ flex: 1, position: "relative" }}>{children}</div>
  </div>
);

/** A screenshot of the real app (public/screens), framed as a window. */
export const AppShot: React.FC<{ file: string; width: number; style?: React.CSSProperties }> = ({
  file,
  width,
  style,
}) => (
  <MacWindow width={width} style={style}>
    <Img src={staticFile(`screens/${file}`)} style={{ width: "100%", display: "block" }} />
  </MacWindow>
);
