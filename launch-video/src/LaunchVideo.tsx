import React from "react";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { slide } from "@remotion/transitions/slide";
import { Cleanup } from "./scenes/Cleanup";
import { Dictate, Languages, PerApp } from "./scenes/Dictate";
import { Hook, Outro, TitleCard } from "./scenes/Opening";
import { Review } from "./scenes/Review";
import { Private, Stats } from "./scenes/Trust";
import { YourWords } from "./scenes/Words";
import { FPS } from "./theme";

/** Scene lengths in seconds, in order; the composition's duration is derived from them. */
export const SCENES = [4, 3.5, 7.5, 6.5, 5.5, 7, 7.5, 7, 6, 5, 5];
export const TRANSITION = 15; // frames
export const DURATION =
  SCENES.reduce((sum, s) => sum + Math.round(s * FPS), 0) - TRANSITION * (SCENES.length - 1);

const cut = () => <TransitionSeries.Transition presentation={fade()} timing={linearTiming({ durationInFrames: TRANSITION })} />;
const push = () => (
  <TransitionSeries.Transition
    presentation={slide({ direction: "from-right" })}
    timing={linearTiming({ durationInFrames: TRANSITION })}
  />
);
const f = (seconds: number) => Math.round(seconds * FPS);

/** The launch video: problem → product → features → trust → where to get it. */
export const LaunchVideo: React.FC = () => (
  <TransitionSeries>
    <TransitionSeries.Sequence name="Hook" durationInFrames={f(SCENES[0])}>
      <Hook />
    </TransitionSeries.Sequence>
    {cut()}
    <TransitionSeries.Sequence name="Title" durationInFrames={f(SCENES[1])}>
      <TitleCard />
    </TransitionSeries.Sequence>
    {cut()}
    <TransitionSeries.Sequence name="Dictate" durationInFrames={f(SCENES[2])}>
      <Dictate />
    </TransitionSeries.Sequence>
    {push()}
    <TransitionSeries.Sequence name="Per-app language" durationInFrames={f(SCENES[3])}>
      <PerApp />
    </TransitionSeries.Sequence>
    {push()}
    <TransitionSeries.Sequence name="Languages" durationInFrames={f(SCENES[4])}>
      <Languages />
    </TransitionSeries.Sequence>
    {push()}
    <TransitionSeries.Sequence name="Review before paste" durationInFrames={f(SCENES[5])}>
      <Review />
    </TransitionSeries.Sequence>
    {push()}
    <TransitionSeries.Sequence name="Fillers and corrections" durationInFrames={f(SCENES[6])}>
      <Cleanup />
    </TransitionSeries.Sequence>
    {push()}
    <TransitionSeries.Sequence name="Your words" durationInFrames={f(SCENES[7])}>
      <YourWords />
    </TransitionSeries.Sequence>
    {push()}
    <TransitionSeries.Sequence name="On-device" durationInFrames={f(SCENES[8])}>
      <Private />
    </TransitionSeries.Sequence>
    {cut()}
    <TransitionSeries.Sequence name="Numbers" durationInFrames={f(SCENES[9])}>
      <Stats />
    </TransitionSeries.Sequence>
    {cut()}
    <TransitionSeries.Sequence name="Outro" durationInFrames={f(SCENES[10])}>
      <Outro />
    </TransitionSeries.Sequence>
  </TransitionSeries>
);
