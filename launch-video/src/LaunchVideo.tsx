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
import { Soundtrack } from "./components/Soundtrack";
import { Voice } from "./components/Voice";
import { BAR, FPS } from "./theme";
import { TAKES, type TakeId } from "./voiceover";

/**
 * The scenes in order, each a whole number of bars of the soundtrack, so
 * every cut starts on a bar line. The pitch: dictation you can trust.
 * `voice`: the take of yours that plays in that scene (src/voiceover.ts).
 */
const SCENES: {
  name: string;
  bars: number;
  push?: boolean;
  voice?: TakeId;
  Scene: React.FC;
}[] = [
  { name: "Hook", bars: 2, Scene: Hook },
  { name: "Title", bars: 2, Scene: TitleCard },
  { name: "Dictate (English)", bars: 4, voice: "mail", Scene: Dictate },
  { name: "Smart review", bars: 3, push: true, Scene: SmartReview },
  { name: "Review panel", bars: 4, push: true, Scene: Review },
  { name: "Never rewrites you", bars: 5, push: true, voice: "fillers", Scene: Cleanup },
  { name: "Your words", bars: 3, push: true, Scene: YourWords },
  { name: "Hinglish", bars: 3, push: true, voice: "chat", Scene: Hinglish },
  { name: "Languages", bars: 2, push: true, Scene: Languages },
  { name: "On-device", bars: 3, push: true, Scene: Private },
  { name: "Promises", bars: 3, Scene: Promises },
  { name: "Outro", bars: 3, Scene: Outro },
];
export const TRANSITION = 15; // frames, about one beat

/** Frame where each scene starts entering: on a bar line, rounded once (no drift). */
export const STARTS = SCENES.map((_, i) =>
  Math.round(
    SCENES.slice(0, i).reduce((bars, s) => bars + s.bars, 0) * BAR * FPS,
  ),
);
const END = Math.round(
  SCENES.reduce((bars, s) => bars + s.bars, 0) * BAR * FPS,
);
// A scene runs until the next one has finished coming in.
const length = (i: number) =>
  (i + 1 < SCENES.length ? STARTS[i + 1] + TRANSITION : END) - STARTS[i];
export const DURATION = END;

/** Seconds of the whole video where you are speaking: the music dips there. */
const SPEAKING = SCENES.flatMap(({ voice }, i) =>
  voice
    ? [[STARTS[i] / FPS + TAKES[voice].at, STARTS[i] / FPS + TAKES[voice].at + TAKES[voice].speech] as const]
    : [],
);

export const LaunchVideo: React.FC = () => (
  <>
    <TransitionSeries>
      {SCENES.flatMap(({ name, push, voice, Scene }, i) => [
        ...(i === 0
          ? []
          : [
              <TransitionSeries.Transition
                key={`t-${name}`}
                presentation={
                  push ? slide({ direction: "from-right" }) : fade()
                }
                timing={linearTiming({ durationInFrames: TRANSITION })}
              />,
            ]),
        <TransitionSeries.Sequence
          key={name}
          name={name}
          durationInFrames={length(i)}
        >
          <Scene />
          {voice ? <Voice id={voice} /> : null}
        </TransitionSeries.Sequence>,
      ])}
    </TransitionSeries>
    <Soundtrack speaking={SPEAKING} />
  </>
);
