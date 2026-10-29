import React from "react";
import { Audio } from "@remotion/media";
import { interpolate, staticFile, useVideoConfig } from "remotion";
import { MUSIC_START } from "../theme";

const LEVEL = 0.8;
/** Under your voice: low enough to hear every word, high enough to keep the groove. */
const DUCKED = 0.2;
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/**
 * Retro Funky Groove by BombinSound (Pixabay 622862, free license). Starts on
 * its first beat so the bar grid in theme.ts lines up with frame 0, dips while
 * you speak (`speaking`, in seconds), and fades out over the last two seconds.
 */
export const Soundtrack: React.FC<{ speaking: readonly (readonly [number, number])[] }> = ({ speaking }) => {
  const { fps, durationInFrames } = useVideoConfig();
  // `f` counts frames from the video's start (the music starts at frame 0).
  const volume = (f: number) => {
    const t = f / fps;
    // Down over 0.3 s just before the first word, back up over 0.5 s after the last.
    const duck = Math.min(
      1,
      ...speaking.map(([from, to]) =>
        interpolate(t, [from - 0.4, from - 0.1, to + 0.1, to + 0.6], [1, DUCKED / LEVEL, DUCKED / LEVEL, 1], clamp),
      ),
    );
    const fadeOut = interpolate(f, [durationInFrames - 2 * fps, durationInFrames - 1], [1, 0], clamp);
    return LEVEL * duck * fadeOut;
  };
  return (
    <Audio
      src={staticFile("music/retro-funky-groove.mp3")}
      trimBefore={Math.round(MUSIC_START * fps)}
      volume={volume}
    />
  );
};
