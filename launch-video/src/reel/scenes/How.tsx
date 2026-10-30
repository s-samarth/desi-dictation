import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { Keycap } from "../../components/Keycap";
import { MacWindow } from "../../components/MacWindow";
import { OverlayPill } from "../../components/OverlayPill";
import { Pasted, SoundBars } from "../../components/Typed";
import { BEAT, color } from "../../theme";
import { beat, Hi, ReelBg, Rise, Slam, Stamp } from "../kit";

const STEPS = ["Hold", "Talk", "Let go"];

/** Hold Right ⌥, speak, release: the Hinglish line lands in a chat. */
export const Demo: React.FC = () => {
  const frame = useCurrentFrame();
  const t = (n: number) => n * BEAT; // beat → seconds, for the launch film's components
  const listening = frame < beat(4.5);
  return (
    <ReelBg>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 50, width: "100%" }}>
        <div style={{ display: "flex", gap: 30, fontSize: 100, fontWeight: 800 }}>
          {STEPS.map((s, i) => (
            <span key={s} style={{ color: frame >= beat(i * 2) ? (i === 1 ? color.saffron : color.text) : "#3a4152" }}>
              {s}
              .
            </span>
          ))}
        </div>
        <Keycap from={t(0.3)} to={t(4.4)} style={{ scale: "1.7", margin: "40px 0" }} />
        <div style={{ height: 90, display: "flex", alignItems: "center" }}>
          <OverlayPill language="Hinglish" phase={listening ? "listening" : "transcribing"} style={{ scale: "1.45" }} />
        </div>
        <SoundBars from={t(0.5)} to={t(4.3)} />
        <MacWindow title="Messages" width={940} height={360}>
          <div style={{ padding: "26px 36px", fontSize: 54, lineHeight: 1.3, color: color.text }}>
            <Pasted at={t(5.4)} text="Haan, kal 5 baje milte hain. Main Rahul ko bhi bol deta hoon." />
          </div>
        </MacWindow>
      </div>
    </ReelBg>
  );
};

/**
 * The pipeline, true to docs/SYSTEM_DESIGN.md: mic → VAD → on-device model
 * (whisper.cpp on Metal) → your words → ⌘V. One step lights per two beats.
 */
const PIPE: [string, string][] = [
  ["Hold ⌥", "The mic records, on your Mac"],
  ["Silero VAD", "Trims the silence and pauses"],
  ["On-device model", "Hinglish Prime · Parakeet · Vaani Hindi, on your Mac's GPU"],
  ["Your words", "Numbers, names, your dictionary"],
  ["Pasted", "Straight into the app you're typing in"],
];
const DOT = [color.saffron, color.blue, color.purple, color.green, color.saffron];

export const Pipeline: React.FC = () => {
  const frame = useCurrentFrame();
  const fill = interpolate(frame, [beat(1), beat(9)], [0, 100], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <ReelBg>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 46, width: "100%" }}>
        <Slam at={0} size={110}>
          How it <Hi>works</Hi>
        </Slam>
        <div style={{ position: "relative", width: "100%", display: "flex", flexDirection: "column", gap: 30 }}>
          {/* The wire between the steps fills as the audio moves down it. */}
          <div style={{ position: "absolute", left: 37, top: 40, bottom: 40, width: 6, background: "#2a3142" }}>
            <div style={{ height: `${fill}%`, background: color.saffron }} />
          </div>
          {PIPE.map(([name, what], i) => (
            <Rise key={name} at={1 + i * 2}>
              <div style={{ display: "flex", gap: 34, alignItems: "center" }}>
                <div
                  style={{
                    flexShrink: 0,
                    width: 80,
                    height: 80,
                    borderRadius: 40,
                    background: DOT[i],
                    display: "flex",
                    justifyContent: "center",
                    alignItems: "center",
                    fontSize: 40,
                    fontWeight: 800,
                    color: color.bg,
                    zIndex: 1,
                  }}
                >
                  {i + 1}
                </div>
                <div>
                  <div style={{ fontSize: 64, fontWeight: 800 }}>{name}</div>
                  <div style={{ fontSize: 40, color: color.dim, lineHeight: 1.25 }}>{what}</div>
                </div>
              </div>
            </Rise>
          ))}
        </div>
        <Stamp at={10}>0 servers involved</Stamp>
      </div>
    </ReelBg>
  );
};
