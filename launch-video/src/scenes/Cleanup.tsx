import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { Backdrop } from "../components/Backdrop";
import { Accent, Caption } from "../components/Caption";
import { color, font } from "../theme";
import { spokenBy } from "../voiceover";

// You say the whole sentence first; the cleanup starts just after.
const S = spokenBy("fillers") + 0.2;
const UMS_GONE = S + 0.8;
const SUGGEST = S + 1.2;
const ACCEPTED = S + 3.4;

/** A span that is struck through at `strikeAt` s and folds away by `goneAt` s. */
const Fold: React.FC<{ children: string; strikeAt: number; goneAt: number; c?: string }> = ({
  children,
  strikeAt,
  goneAt,
  c = color.red,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
  return (
    <span
      style={{
        display: "inline-block",
        whiteSpace: "pre",
        overflow: "hidden",
        verticalAlign: "bottom",
        maxWidth: interpolate(t, [goneAt - 0.4, goneAt], [900, 0], clamp),
        opacity: interpolate(t, [goneAt - 0.4, goneAt], [1, 0], clamp),
        color: t >= strikeAt ? c : color.text,
        textDecoration: t >= strikeAt ? "line-through" : "none",
      }}
    >
      {children}
    </span>
  );
};

/** um/uh go on their own; "two, no, make it three" is offered as three. */
export const Cleanup: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
  return (
    <Backdrop>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 90 }}>
        <Caption title={<>It never rewrites you <Accent>behind your back</Accent>.</>} sub="Ums go. Second thoughts become suggestions. You decide." />
        <div style={{ fontFamily: font, fontSize: 64, color: color.text, position: "relative" }}>
          <Fold strikeAt={S} goneAt={UMS_GONE}>{"Um, "}</Fold>
          <span>{t >= UMS_GONE ? "So" : "so"} we should</span>
          <Fold strikeAt={S} goneAt={UMS_GONE}>{", uh,"}</Fold>
          <span> meet at </span>
          <Fold strikeAt={ACCEPTED - 0.6} goneAt={ACCEPTED} c={color.purple}>{"two, no, make it "}</Fold>
          <span
            style={{
              borderBottom: `5px solid ${t >= SUGGEST && t < ACCEPTED ? color.purple : "transparent"}`,
              color: t >= ACCEPTED ? color.green : color.text,
            }}
          >
            three
          </span>
          <span>.</span>
          <div
            style={{
              position: "absolute",
              left: "50%",
              translate: "-50% 0",
              top: 110,
              whiteSpace: "nowrap",
              fontSize: 40,
              padding: "16px 30px",
              borderRadius: 18,
              background: color.bgSoft,
              border: `2px solid ${color.purple}`,
              opacity: interpolate(t, [SUGGEST, SUGGEST + 0.4, ACCEPTED, ACCEPTED + 0.4], [0, 1, 1, 0], clamp),
            }}
          >
            You probably meant: <b>meet at three</b> &nbsp;
            <span style={{ color: color.dim }}>press 1</span>
          </div>
        </div>
        <div
          style={{
            fontFamily: font,
            fontSize: 36,
            color: color.dim,
            opacity: interpolate(t, [ACCEPTED + 0.4, ACCEPTED + 0.8], [0, 1], clamp),
          }}
        >
          Nothing changes until you press 1.
        </div>
      </div>
    </Backdrop>
  );
};
