import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { color, font } from "../theme";

/**
 * The app's recording overlay (OverlayPanel.swift), redrawn at video scale:
 * "● Listening · Hinglish · esc to cancel". `rule` names a per-app rule and
 * turns the badge orange, as the app does.
 */
export const OverlayPill: React.FC<{
  language: string;
  rule?: string;
  phase?: "listening" | "transcribing";
  style?: React.CSSProperties;
}> = ({ language, rule, phase = "listening", style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pulse = (Math.sin((frame / fps) * Math.PI * 2 * 0.65) + 1) / 2;
  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 18,
        padding: "18px 30px",
        borderRadius: 999,
        background: "rgba(40,40,46,0.88)",
        border: "1px solid rgba(255,255,255,0.14)",
        boxShadow: "0 20px 60px rgba(0,0,0,0.45)",
        fontFamily: font,
        color: color.text,
        ...style,
      }}
    >
      {phase === "listening" ? (
        <div
          style={{
            width: 18,
            height: 18,
            borderRadius: 9,
            background: color.red,
            scale: String(0.65 + 0.35 * pulse),
            opacity: 0.55 + 0.45 * pulse,
          }}
        />
      ) : (
        <div
          style={{
            width: 20,
            height: 20,
            borderRadius: 10,
            border: "3px solid rgba(255,255,255,0.25)",
            borderTopColor: color.text,
            rotate: `${interpolate(frame, [0, fps], [0, 360])}deg`,
          }}
        />
      )}
      <span style={{ fontSize: 28, fontWeight: 600 }}>{phase === "listening" ? "Listening" : "Transcribing"}</span>
      <span
        style={{
          fontSize: 22,
          fontWeight: 600,
          padding: "4px 14px",
          borderRadius: 999,
          background: rule ? "rgba(255,153,51,0.35)" : "rgba(255,255,255,0.14)",
        }}
      >
        {rule ? `${language} · ${rule} rule` : language}
      </span>
      {phase === "listening" ? <span style={{ fontSize: 22, color: color.dim }}>esc to cancel</span> : null}
    </div>
  );
};
