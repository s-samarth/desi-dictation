import React from "react";
import { interpolate, Sequence, useCurrentFrame, useVideoConfig } from "remotion";
import { Backdrop } from "../components/Backdrop";
import { Accent, Caption } from "../components/Caption";
import { color, font } from "../theme";

/** A word that flips from what was heard to what you meant at `at` s. */
const Flip: React.FC<{ heard: string; meant: string; at: number }> = ({ heard, meant, at }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const done = frame >= at * fps;
  return (
    <span
      style={{
        color: done ? color.green : color.text,
        borderBottom: `4px solid ${done ? color.green : "transparent"}`,
        opacity: interpolate(frame, [at * fps - 4, at * fps, at * fps + 4], [1, 0.2, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        }),
      }}
    >
      {done ? meant : heard}
    </span>
  );
};

const Line: React.FC<{ children: React.ReactNode; note: string; noteColor: string }> = ({ children, note, noteColor }) => (
  <div style={{ display: "flex", alignItems: "baseline", gap: 40, fontFamily: font }}>
    <div style={{ fontSize: 58, color: color.text, width: 1050 }}>{children}</div>
    <div style={{ fontSize: 34, color: noteColor, width: 520 }}>{note}</div>
  </div>
);

/** Your words: names written your way; "When it fits" only where the sentence says so. */
export const YourWords: React.FC = () => {
  const { fps } = useVideoConfig();
  return (
    <Backdrop>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 70 }}>
        <Caption
          title={<>Teach it your names <Accent>once</Accent>.</>}
          sub="Fix a word, choose to remember it. Smart enough to know when it fits."
        />
        <div style={{ display: "flex", flexDirection: "column", gap: 44 }}>
          <Sequence from={0.8 * fps} layout="none">
            <Line note="Always: your spelling" noteColor={color.saffron}>
              Send the deck to <Flip heard="Cavya" meant="Kavya" at={1.6} />
            </Line>
          </Sequence>
          <Sequence from={2.4 * fps} layout="none">
            <Line note="When it fits: about Claude" noteColor={color.purple}>
              Ask <Flip heard="cloud" meant="Claude" at={1.0} /> to review the PR
            </Line>
          </Sequence>
          <Sequence from={4.0 * fps} layout="none">
            <Line note="…and left alone here" noteColor={color.dim}>
              Upload the photos to the cloud
            </Line>
          </Sequence>
        </div>
      </div>
    </Backdrop>
  );
};
