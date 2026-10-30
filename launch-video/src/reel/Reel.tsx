import React from "react";
import { AbsoluteFill, Sequence } from "remotion";
import { Soundtrack } from "../components/Soundtrack";
import { BAR, FPS } from "../theme";
import { Flash } from "./kit";
import { Hook, Languages, Title } from "./scenes/Open";
import { Demo, Pipeline } from "./scenes/How";
import { AsksWhenUnsure, NoRewrite } from "./scenes/Trust";
import { Cta, Privacy } from "./scenes/Close";

/**
 * The vertical reel (1080×1920, ~41 s): hard cuts on bar lines with a flash,
 * no voice, the launch film's track. The track's quiet intro carries the jab,
 * its groove kicks in on the title (beat 7), and its breakdown (bar 18)
 * lands on the call to action.
 */
const SCENES: { name: string; bars: number; Scene: React.FC }[] = [
  { name: "Hook", bars: 2, Scene: Hook },
  { name: "Title", bars: 2, Scene: Title },
  { name: "Languages", bars: 2, Scene: Languages },
  { name: "Demo", bars: 2, Scene: Demo },
  { name: "How it works", bars: 3, Scene: Pipeline },
  { name: "No rewrite", bars: 2, Scene: NoRewrite },
  { name: "Asks when unsure", bars: 3, Scene: AsksWhenUnsure },
  { name: "Privacy", bars: 2, Scene: Privacy },
  { name: "Get it", bars: 3, Scene: Cta },
];

const barsBefore = (i: number) => SCENES.slice(0, i).reduce((n, s) => n + s.bars, 0);
const START = SCENES.map((_, i) => Math.round(barsBefore(i) * BAR * FPS));
export const REEL_DURATION = Math.round(barsBefore(SCENES.length) * BAR * FPS);

export const Reel: React.FC = () => (
  <AbsoluteFill>
    {SCENES.map(({ name, Scene }, i) => (
      <Sequence
        key={name}
        name={name}
        from={START[i]}
        durationInFrames={(START[i + 1] ?? REEL_DURATION) - START[i]}
      >
        <Scene />
        {i > 0 ? <Flash /> : null}
      </Sequence>
    ))}
    <Soundtrack speaking={[]} />
  </AbsoluteFill>
);
