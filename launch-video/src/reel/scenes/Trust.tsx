import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { color } from "../../theme";
import { beat, Card, Hi, ReelBg, Rise, Slam, Stamp } from "../kit";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** A filler that folds away on beat `at`: struck through, then gone. */
const Filler: React.FC<{ word: string; at: number }> = ({ word, at }) => {
  const frame = useCurrentFrame();
  const fold = interpolate(frame, [beat(at), beat(at) + 8], [1, 0], clamp);
  return (
    <span
      style={{
        display: "inline-block",
        maxWidth: `${fold * 4}em`,
        overflow: "hidden",
        verticalAlign: "bottom",
        whiteSpace: "nowrap",
        opacity: fold,
        color: color.red,
        textDecoration: frame >= beat(at - 1) ? `line-through ${color.red} 6px` : "none",
      }}
    >
      {word}&nbsp;
    </span>
  );
};

/** A word that gains its capital once the filler before it folds away. */
const Cap: React.FC<{ at: number; word: string }> = ({ at, word }) => {
  const frame = useCurrentFrame();
  return <>{frame >= beat(at) + 8 ? word[0].toUpperCase() + word.slice(1) : word}</>;
};

/** It cleans the ums, and leaves every real word of yours alone. */
export const NoRewrite: React.FC = () => (
  <ReelBg>
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 56, width: "100%" }}>
      <Slam at={0} size={118}>
        It says what
        <br />
        <Hi>you</Hi> said.
      </Slam>
      <Rise at={1} style={{ width: "100%" }}>
        <Card style={{ fontSize: 64, lineHeight: 1.3 }}>
          <Filler word="Um," at={3} />
          <Cap at={3} word="so" /> we should, <Filler word="uh," at={3.5} />
          send the deck tonight.
        </Card>
      </Rise>
      <Rise at={5}>
        <div style={{ fontSize: 58, fontWeight: 700, textAlign: "center", lineHeight: 1.3 }}>
          Ums gone. <Hi c={color.green}>Not one real word changed.</Hi>
        </div>
      </Rise>
      <Stamp at={6.5} c={color.saffron} rotate={4}>
        No AI rewrite
      </Stamp>
    </div>
  </ReelBg>
);

/** A word it isn't sure of: wavy saffron underline, then the fix on beat `fix`. */
const Unsure: React.FC<{ heard: string; meant: string; fix: number }> = ({ heard, meant, fix }) => {
  const frame = useCurrentFrame();
  const fixed = frame >= beat(fix);
  return (
    <span
      style={{
        color: fixed ? color.green : color.text,
        textDecoration: fixed ? "none" : `underline wavy ${color.saffron}`,
        textUnderlineOffset: 12,
        textDecorationThickness: 4,
      }}
    >
      {fixed ? meant : heard}
    </span>
  );
};

/** Sure → pasted, no pop-up. Unsure → it asks about just those words. */
export const AsksWhenUnsure: React.FC = () => (
  <ReelBg>
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 40, width: "100%" }}>
      <Slam at={0} size={108}>
        It only asks
        <br />
        when it's <Hi>unsure.</Hi>
      </Slam>
      <Rise at={2} style={{ width: "100%" }}>
        <Card style={{ fontSize: 56 }}>Let's push the launch to Friday.</Card>
        <Verdict at={3} c={color.green} text="Sure → pasted. No pop-up." />
      </Rise>
      <Rise at={5} style={{ width: "100%" }}>
        <Card style={{ fontSize: 56 }}>
          Ask <Unsure heard="cloud" meant="Claude" fix={8} /> to send the deck to{" "}
          <Unsure heard="Cavya" meant="Kavya" fix={8.5} />.
        </Card>
        <Verdict at={6} c={color.saffron} text="Unsure → check just 2 words." />
      </Rise>
      <Slam at={10} size={100} shake>
        No spam.
        <br />
        <Hi>No nagging.</Hi>
      </Slam>
    </div>
  </ReelBg>
);

const Verdict: React.FC<{ at: number; c: string; text: string }> = ({ at, c, text }) => (
  <Rise at={at}>
    <div style={{ marginTop: 18, fontSize: 50, fontWeight: 800, color: c, paddingLeft: 12 }}>{text}</div>
  </Rise>
);
