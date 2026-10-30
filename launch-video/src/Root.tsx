import { Composition } from "remotion";
import { DURATION, LaunchVideo } from "./LaunchVideo";
import { FPS, HEIGHT, WIDTH } from "./theme";
import { Reel, REEL_DURATION } from "./reel/Reel";
import { REEL_H, REEL_W } from "./reel/kit";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="Launch"
        component={LaunchVideo}
        durationInFrames={DURATION}
        fps={FPS}
        width={WIDTH}
        height={HEIGHT}
      />
      <Composition
        id="Reel"
        component={Reel}
        durationInFrames={REEL_DURATION}
        fps={FPS}
        width={REEL_W}
        height={REEL_H}
      />
    </>
  );
};
