import React from "react";
import { AbsoluteFill, Img, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { color } from "../../theme";
import { beat, Hi, ReelBg, Rise, Slam } from "../kit";

/** One word per beat, each on its own colour: the flashiest four beats of the reel. */
const WORDS: [string, string, string][] = [
  ["FREE.", color.saffron, color.bg],
  ["LOCAL.", "#f5f5f7", color.bg],
  ["OFFLINE.", color.green, color.bg],
  ["PRIVATE.", color.blue, "#f5f5f7"],
];

export const Privacy: React.FC = () => {
  const frame = useCurrentFrame();
  const i = Math.floor(frame / beat(1));
  if (i < WORDS.length) {
    const [word, bg, ink] = WORDS[i];
    return (
      <AbsoluteFill style={{ background: bg }}>
        <ReelBg tint={bg}>
          <Slam at={i} size={190} style={{ color: ink, letterSpacing: -6 }}>
            {word}
          </Slam>
        </ReelBg>
      </AbsoluteFill>
    );
  }
  return (
    <ReelBg>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 44 }}>
        <Slam at={4} size={112} shake>
          Your voice <Hi c={color.green}>never</Hi>
          <br />
          leaves your Mac.
        </Slam>
        <Rise at={5}>
          <div style={{ fontSize: 50, color: color.dim, textAlign: "center", lineHeight: 1.5 }}>
            No cloud · No account
            <br />
            No subscription · Works offline
          </div>
        </Rise>
      </div>
    </ReelBg>
  );
};

/** Get your copy: the site has the download and the full launch film. */
export const Cta: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame, fps, config: { damping: 10, stiffness: 200 } });
  return (
    <ReelBg>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 36 }}>
        <Img src={staticFile("icon.png")} style={{ width: 260, height: 260, scale: String(pop) }} />
        <Slam at={1} size={128}>
          Get your copy.
        </Slam>
        <Slam at={2} size={128} shake>
          <Hi>It's free.</Hi>
        </Slam>
        <Rise at={4}>
          <div
            style={{
              marginTop: 10,
              padding: "26px 36px",
              borderRadius: 999,
              background: color.saffron,
              color: color.bg,
              fontSize: 41,
              fontWeight: 800,
              letterSpacing: -0.5,
              whiteSpace: "nowrap",
            }}
          >
            samarthsaraswat.com/desi-dictation
          </div>
        </Rise>
        <Rise at={6}>
          <div style={{ fontSize: 50, fontWeight: 700, textAlign: "center" }}>
            ▶ Watch the full launch film there
          </div>
        </Rise>
        <Rise at={8}>
          <div style={{ fontSize: 42, color: color.dim, textAlign: "center", lineHeight: 1.45 }}>
            Mac · Apple Silicon · Free beta
            <br />
            Open source on GitHub ⭐
          </div>
        </Rise>
      </div>
    </ReelBg>
  );
};
