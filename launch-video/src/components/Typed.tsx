import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { color } from "../theme";

/**
 * Text that lands the way a dictation does: nothing until `at` seconds, then
 * the whole sentence fades in over a few frames (it pastes; it isn't typed).
 * Before that, a blinking caret.
 */
export const Pasted: React.FC<{ text: string; at: number; style?: React.CSSProperties }> = ({
  text,
  at,
  style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const shown = frame >= at * fps;
  const caretOn = Math.floor(frame / (fps / 2)) % 2 === 0;
  return (
    <span style={style}>
      {shown ? (
        <span
          style={{
            opacity: interpolate(frame, [at * fps, at * fps + 6], [0, 1], { extrapolateRight: "clamp" }),
          }}
        >
          {text}
        </span>
      ) : null}
      <span
        style={{
          display: "inline-block",
          width: 3,
          height: "1.1em",
          marginLeft: 2,
          verticalAlign: "text-bottom",
          background: caretOn ? color.blue : "transparent",
        }}
      />
    </span>
  );
};

/** Live sound bars while someone speaks, between `from` and `to` seconds. */
export const SoundBars: React.FC<{ from: number; to: number; style?: React.CSSProperties }> = ({
  from,
  to,
  style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const on = t >= from && t <= to;
  return (
    <div style={{ display: "flex", gap: 8, alignItems: "center", height: 80, ...style }}>
      {Array.from({ length: 18 }, (_, i) => {
        const h = on ? 14 + Math.abs(Math.sin(t * 9 + i * 1.7) * Math.cos(t * 4 + i)) * 60 : 8;
        return <div key={i} style={{ width: 8, height: h, borderRadius: 4, background: color.saffron, opacity: on ? 1 : 0.3 }} />;
      })}
    </div>
  );
};
