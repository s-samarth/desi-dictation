import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { color } from "../theme";
import { Keycap } from "./Keycap";
import { MacWindow } from "./MacWindow";
import { OverlayPill } from "./OverlayPill";
import { Pasted, SoundBars } from "./Typed";

/**
 * One dictation, start to finish: the key goes down, the overlay listens,
 * the key comes up, it transcribes, the text lands in the field. Timings in
 * seconds from the scene start.
 */
export const DictationDemo: React.FC<{
  window: string;
  above?: React.ReactNode;
  text: string;
  language: string;
  rule?: string;
  talk?: [number, number];
  width?: number;
}> = ({ window, above, text, language, rule, talk = [0.8, 3.6], width = 1200 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const [from, to] = talk;
  const pasteAt = to + 0.5;
  const pillShown = t >= from && t < pasteAt;
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 40 }}>
      <MacWindow title={window} width={width} height={460}>
        <div style={{ position: "absolute", inset: 0, padding: "10px 40px 36px", display: "flex", flexDirection: "column" }}>
          <div style={{ flex: 1 }}>{above}</div>
          <div
            style={{
              minHeight: 84,
              borderRadius: 18,
              border: `2px solid ${color.blue}`,
              background: "#2a2a2e",
              padding: "18px 24px",
              fontSize: 36,
              lineHeight: 1.35,
              color: color.text,
            }}
          >
            <Pasted text={text} at={pasteAt} />
          </div>
        </div>
      </MacWindow>
      <div style={{ display: "flex", alignItems: "center", gap: 40, height: 140 }}>
        <Keycap from={from} to={to} />
        <div
          style={{
            opacity: interpolate(t, [from, from + 0.2, pasteAt - 0.1, pasteAt], [0, 1, 1, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          {pillShown ? (
            <OverlayPill language={language} rule={rule} phase={t <= to ? "listening" : "transcribing"} />
          ) : (
            <OverlayPill language={language} rule={rule} />
          )}
        </div>
        <SoundBars from={from} to={to} style={{ opacity: t <= to ? 1 : 0.2 }} />
      </div>
    </div>
  );
};

/** A received chat bubble. */
export const Bubble: React.FC<{ children: React.ReactNode; mine?: boolean }> = ({ children, mine }) => (
  <div
    style={{
      alignSelf: mine ? "flex-end" : "flex-start",
      maxWidth: "70%",
      marginTop: 18,
      padding: "16px 24px",
      borderRadius: 24,
      fontSize: 34,
      color: color.text,
      background: mine ? "#1f6f43" : "#3a3a40",
    }}
  >
    {children}
  </div>
);
