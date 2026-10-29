import React from "react";
import { Audio } from "@remotion/media";
import { Sequence, staticFile, useVideoConfig } from "remotion";
import { LEAD, TAKES, type TakeId } from "../voiceover";

/** One take, placed so its speech starts at TAKES[id].at in the scene. */
export const Voice: React.FC<{ id: TakeId }> = ({ id }) => {
  const { fps } = useVideoConfig();
  return (
    <Sequence from={Math.round((TAKES[id].at - LEAD) * fps)} layout="none" name={`Voice: ${id}`}>
      <Audio src={staticFile(`voice/mix/${id}.wav`)} />
    </Sequence>
  );
};
