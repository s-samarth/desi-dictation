import React from "react";
import { Video } from "@remotion/media";
import { AbsoluteFill, Img, interpolate, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Backdrop } from "../components/Backdrop";
import { Accent, Caption } from "../components/Caption";
import { BAR, color, font } from "../theme";

/**
 * The hook: someone talking to their laptop (Pexels 7251216, free license),
 * and the problem with dictation beside her.
 */
export const Hook: React.FC = () => {
  const { fps } = useVideoConfig();
  return (
    <AbsoluteFill style={{ backgroundColor: color.bg }}>
      {/* She sits in the middle of the shot: move her into the left third, clear of the text. */}
      <AbsoluteFill style={{ translate: "-460px 0px" }}>
        <Video src={staticFile("clips/hook-woman-laptop.mp4")} muted objectFit="cover" style={{ width: "100%", height: "100%" }} />
      </AbsoluteFill>
      <AbsoluteFill
        style={{
          background: "linear-gradient(90deg, rgba(11,15,26,0.1) 25%, rgba(11,15,26,0.8) 48%, rgba(11,15,26,1) 62%)",
        }}
      />
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "flex-end", paddingRight: 120 }}>
        <div style={{ width: 860, display: "flex", flexDirection: "column", gap: 34 }}>
          <Caption align="left" title={<>Most dictation apps <Accent>guess</Accent>.</>} />
          <Sequence from={Math.round(BAR * fps)} layout="none">
            <Caption align="left" title="And you find out after you hit send." style={{ color: color.dim }} />
          </Sequence>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

/** Icon, name, one-line promise. */
export const TitleCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame, fps, config: { damping: 14 } });
  return (
    <Backdrop>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 36, fontFamily: font }}>
        <Img src={staticFile("icon.png")} style={{ width: 260, height: 260, scale: String(pop) }} />
        <div style={{ fontSize: 120, fontWeight: 800, letterSpacing: -3, color: color.text }}>Desi Dictation</div>
        <div
          style={{
            fontSize: 48,
            color: color.dim,
            opacity: interpolate(frame, [0.6 * fps, 1.1 * fps], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          Dictation you can trust. English, Hinglish and हिन्दी.
        </div>
      </div>
    </Backdrop>
  );
};

/** Closing card: where to get it. */
export const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame, fps, config: { damping: 14 } });
  return (
    <Backdrop>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 34, fontFamily: font }}>
        <Img src={staticFile("icon.png")} style={{ width: 200, height: 200, scale: String(pop) }} />
        <div style={{ fontSize: 110, fontWeight: 800, letterSpacing: -3, color: color.text }}>Desi Dictation</div>
        <div style={{ fontSize: 46, color: color.dim }}>Dictation you can trust. On your Mac.</div>
        <div
          style={{
            marginTop: 20,
            fontSize: 40,
            fontWeight: 600,
            color: color.text,
            padding: "22px 44px",
            borderRadius: 999,
            background: color.saffron,
            opacity: interpolate(frame, [0.8 * fps, 1.3 * fps], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          github.com/s-samarth/desi-dictation
        </div>
        <div style={{ fontSize: 30, color: color.dim }}>For Apple Silicon Macs</div>
      </div>
    </Backdrop>
  );
};
