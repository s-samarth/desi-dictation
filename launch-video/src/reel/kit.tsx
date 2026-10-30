import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { BEAT, color, FPS, font } from "../theme";

/**
 * The reel's building blocks. Every scene starts on a bar line, so "beat n"
 * inside a scene is always on the music's grid.
 */
export const REEL_W = 1080;
export const REEL_H = 1920;

/** Frame of beat `n` from the start of the scene. */
export const beat = (n: number) => Math.round(n * BEAT * FPS);

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/**
 * Dark backdrop with the tricolor glows, and a small zoom punch on every beat
 * so even a still frame moves with the music.
 */
export const ReelBg: React.FC<{ children?: React.ReactNode; tint?: string }> = ({ children, tint }) => {
  const frame = useCurrentFrame();
  const phase = (frame / FPS / BEAT) % 1;
  const punch = 1 + 0.022 * Math.exp(-7 * phase);
  return (
    <AbsoluteFill
      style={{
        backgroundColor: tint ?? color.bg,
        backgroundImage: tint
          ? undefined
          : `radial-gradient(circle at 15% ${10 + (frame % 300) / 30}%, rgba(255,153,51,0.24), transparent 42%),
             radial-gradient(circle at 90% ${92 - (frame % 300) / 30}%, rgba(34,169,90,0.22), transparent 42%)`,
        fontFamily: font,
        color: color.text,
      }}
    >
      <AbsoluteFill
        style={{
          scale: String(punch),
          justifyContent: "center",
          alignItems: "center",
          padding: "230px 70px 340px",
        }}
      >
        {children}
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

/** A white flash at the cut: the reel's hard-cut accent. */
export const Flash: React.FC<{ at?: number }> = ({ at = 0 }) => {
  const frame = useCurrentFrame();
  const o = interpolate(frame, [beat(at), beat(at) + 5], [0.75, 0], clamp);
  return o > 0 ? <AbsoluteFill style={{ background: "#fff", opacity: o, pointerEvents: "none" }} /> : null;
};

/**
 * Text that slams in on beat `at`: big and blurred, then snapping to size.
 * `shake` adds a short camera jolt for the punchlines.
 */
export const Slam: React.FC<{
  at: number;
  size?: number;
  shake?: boolean;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ at, size = 110, shake, children, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = frame - beat(at);
  if (f < 0) return null;
  const s = spring({ frame: f, fps, config: { damping: 16, stiffness: 260, mass: 0.6 } });
  const jolt = shake ? Math.sin(f * 2.3) * 14 * Math.exp(-f / 4) : 0;
  return (
    <div
      style={{
        fontSize: size,
        fontWeight: 800,
        letterSpacing: -size * 0.03,
        lineHeight: 1.04,
        textAlign: "center",
        scale: String(interpolate(s, [0, 1], [1.7, 1])),
        opacity: interpolate(f, [0, 3], [0, 1], clamp),
        filter: `blur(${interpolate(f, [0, 5], [10, 0], clamp)}px)`,
        translate: `${jolt}px 0px`,
        ...style,
      }}
    >
      {children}
    </div>
  );
};

/** Something that rises in on beat `at` (cards, rows, labels). */
export const Rise: React.FC<{ at: number; children: React.ReactNode; style?: React.CSSProperties }> = ({
  at,
  children,
  style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = frame - beat(at);
  if (f < 0) return null;
  const s = spring({ frame: f, fps, config: { damping: 18, stiffness: 220 } });
  return (
    <div style={{ opacity: Math.min(1, f / 4), translate: `0px ${interpolate(s, [0, 1], [70, 0])}px`, ...style }}>
      {children}
    </div>
  );
};

/** A word in an accent colour. */
export const Hi: React.FC<{ c?: string; children: React.ReactNode }> = ({ c = color.saffron, children }) => (
  <span style={{ color: c }}>{children}</span>
);

/** A rounded card on the dark backdrop. */
export const Card: React.FC<{ children: React.ReactNode; style?: React.CSSProperties }> = ({ children, style }) => (
  <div
    style={{
      padding: "34px 40px",
      borderRadius: 30,
      background: color.bgSoft,
      border: `1px solid ${color.panelLine}`,
      boxShadow: "0 30px 80px rgba(0,0,0,0.45)",
      ...style,
    }}
  >
    {children}
  </div>
);

/** The tricolor bar that sweeps in under a headline on beat `at`. */
export const Tricolor: React.FC<{ at: number; width?: number }> = ({ at, width = 520 }) => {
  const frame = useCurrentFrame();
  const w = interpolate(frame, [beat(at), beat(at) + 10], [0, width], clamp);
  return (
    <div style={{ display: "flex", width: w, height: 14, borderRadius: 7, overflow: "hidden" }}>
      <div style={{ flex: 1, background: color.saffron }} />
      <div style={{ flex: 1, background: "#f5f5f7" }} />
      <div style={{ flex: 1, background: color.green }} />
    </div>
  );
};

/** A stamp that thumps down at an angle on beat `at`. */
export const Stamp: React.FC<{ at: number; c?: string; rotate?: number; children: React.ReactNode }> = ({
  at,
  c = color.green,
  rotate = -6,
  children,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const f = frame - beat(at);
  if (f < 0) return null;
  const s = spring({ frame: f, fps, config: { damping: 11, stiffness: 300 } });
  return (
    <div
      style={{
        display: "inline-block",
        padding: "14px 34px",
        border: `6px solid ${c}`,
        borderRadius: 18,
        color: c,
        fontSize: 64,
        fontWeight: 800,
        letterSpacing: 1,
        textTransform: "uppercase",
        rotate: `${rotate}deg`,
        scale: String(interpolate(s, [0, 1], [2.4, 1])),
        opacity: Math.min(1, f / 3),
      }}
    >
      {children}
    </div>
  );
};
