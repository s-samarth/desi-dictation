import React from "react";
import { Audio } from "@remotion/media";
import { interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { MUSIC_START } from "../theme";

/**
 * Retro Funky Groove by BombinSound (Pixabay 622862, free license). Starts on
 * its first beat so the bar grid in theme.ts lines up with frame 0, and fades
 * out over the last two seconds.
 */
export const Soundtrack: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  return (
    <Audio
      src={staticFile("music/retro-funky-groove.mp3")}
      trimBefore={Math.round(MUSIC_START * fps)}
      volume={interpolate(frame, [durationInFrames - 2 * fps, durationInFrames - 1], [0.8, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })}
    />
  );
};
