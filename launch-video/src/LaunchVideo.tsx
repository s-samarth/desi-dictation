import React from "react";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { slide } from "@remotion/transitions/slide";
import { Cleanup } from "./scenes/Cleanup";
import { Dictate, Hinglish, Languages } from "./scenes/Dictate";
import { Hook, Outro, TitleCard } from "./scenes/Opening";
import { Review } from "./scenes/Review";
import { SmartReview } from "./scenes/SmartReview";
import { Private, Promises } from "./scenes/Trust";
import { YourWords } from "./scenes/Words";
import { FPS } from "./theme";

/** The scenes in order, with their lengths in seconds. The pitch: dictation you can trust. */
const SCENES: { name: string; seconds: number; push?: boolean; Scene: React.FC }[] = [
  { name: "Hook", seconds: 4, Scene: Hook },
  { name: "Title", seconds: 3.5, Scene: TitleCard },
  { name: "Dictate (English)", seconds: 7, Scene: Dictate },
  { name: "Smart review", seconds: 7, push: true, Scene: SmartReview },
  { name: "Review panel", seconds: 7, push: true, Scene: Review },
  { name: "Never rewrites you", seconds: 7.5, push: true, Scene: Cleanup },
  { name: "Your words", seconds: 6.5, push: true, Scene: YourWords },
  { name: "Hinglish", seconds: 6.5, push: true, Scene: Hinglish },
  { name: "Languages", seconds: 4.5, push: true, Scene: Languages },
  { name: "On-device", seconds: 6, push: true, Scene: Private },
  { name: "Promises", seconds: 6.5, Scene: Promises },
  { name: "Outro", seconds: 5, Scene: Outro },
];
export const TRANSITION = 15; // frames
const f = (seconds: number) => Math.round(seconds * FPS);
export const DURATION = SCENES.reduce((sum, s) => sum + f(s.seconds), 0) - TRANSITION * (SCENES.length - 1);

/** Scene starts in frames, for rendering one still per scene. */
export const STARTS = SCENES.map((_, i) =>
  SCENES.slice(0, i).reduce((sum, s) => sum + f(s.seconds) - TRANSITION, 0));

export const LaunchVideo: React.FC = () => (
  <TransitionSeries>
    {SCENES.flatMap(({ name, seconds, push, Scene }, i) => [
      ...(i === 0
        ? []
        : [
            <TransitionSeries.Transition
              key={`t-${name}`}
              presentation={push ? slide({ direction: "from-right" }) : fade()}
              timing={linearTiming({ durationInFrames: TRANSITION })}
            />,
          ]),
      <TransitionSeries.Sequence key={name} name={name} durationInFrames={f(seconds)}>
        <Scene />
      </TransitionSeries.Sequence>,
    ])}
  </TransitionSeries>
);
