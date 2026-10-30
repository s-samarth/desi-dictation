import React from "react";
import { Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { color } from "../../theme";
import { beat, Hi, ReelBg, Rise, Slam, Tricolor } from "../kit";

/**
 * The jab, over the music's quiet intro. Every line is a claim from the
 * website's comparison table (s-samarth/src/data/ddCompare.ts, checked July 2026).
 */
const JABS = ["Your voice goes to their cloud", "$12–15 a month", "AI auto-edits what you said"];

export const Hook: React.FC = () => {
  const frame = useCurrentFrame();
  // The red line through "Wispr Flow?" on the punchline.
  const strike = interpolate(frame, [beat(6), beat(6) + 6], [0, 100], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <ReelBg>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 46 }}>
        <div style={{ position: "relative" }}>
          <Slam at={0} size={150} style={{ whiteSpace: "nowrap" }}>
            Wispr Flow<Hi>?</Hi>
          </Slam>
          <div
            style={{
              position: "absolute",
              left: -20,
              top: "52%",
              height: 16,
              width: `calc(${strike}% + 40px)`,
              background: color.red,
              borderRadius: 8,
              rotate: "-4deg",
              opacity: strike > 0 ? 1 : 0,
            }}
          />
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 22, width: "100%" }}>
          {JABS.map((j, i) => (
            <Rise key={j} at={2 + i}>
              <div style={{ fontSize: 58, fontWeight: 700, display: "flex", gap: 22, alignItems: "center" }}>
                <span style={{ color: color.red, fontWeight: 800 }}>✕</span>
                {j}
              </div>
            </Rise>
          ))}
        </div>
        <Slam at={6} size={108} shake>
          Not built for how <Hi>India talks.</Hi>
        </Slam>
      </div>
    </ReelBg>
  );
};

/** The groove kicks in: the name, big. */
export const Title: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: frame - beat(1), fps, config: { damping: 10, stiffness: 200 } });
  return (
    <ReelBg>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 40 }}>
        <Slam at={0} size={76} style={{ color: color.dim }}>
          So I built
        </Slam>
        <Img
          src={staticFile("icon.png")}
          style={{ width: 340, height: 340, scale: String(Math.max(0, pop)), rotate: `${(1 - pop) * -25}deg` }}
        />
        <Slam at={2} size={170} shake>
          Desi
          <br />
          Dictation
        </Slam>
        <Tricolor at={3} />
        <Slam at={4} size={72}>
          Dictation you can <Hi>trust.</Hi>
        </Slam>
      </div>
    </ReelBg>
  );
};

/** The three languages, one per beat, each with a line you'd actually say. */
const LANGS: [string, string, string][] = [
  ["English", "Can we move the review to Thursday?", color.blue],
  ["Hinglish", "Kal meeting hai, deck ready rakhna.", color.saffron],
  ["हिन्दी", "कल की मीटिंग पाँच बजे है।", color.green],
];

export const Languages: React.FC = () => (
  <ReelBg>
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 44, width: "100%" }}>
      <Slam at={0} size={112}>
        Talk the way
        <br />
        you <Hi>actually</Hi> talk.
      </Slam>
      {LANGS.map(([name, line, c], i) => (
        <Rise key={name} at={2 + i * 1.5} style={{ width: "100%" }}>
          <div
            style={{
              padding: "30px 40px",
              borderRadius: 28,
              background: "rgba(20,26,42,0.92)",
              borderLeft: `14px solid ${c}`,
            }}
          >
            <div style={{ fontSize: 72, fontWeight: 800, color: c }}>{name}</div>
            <div style={{ marginTop: 8, fontSize: 52, color: color.text }}>“{line}”</div>
          </div>
        </Rise>
      ))}
    </div>
  </ReelBg>
);
