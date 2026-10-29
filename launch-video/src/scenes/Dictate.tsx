import React from "react";
import { Sequence, useVideoConfig } from "remotion";
import { Backdrop } from "../components/Backdrop";
import { Accent, Caption } from "../components/Caption";
import { Bubble, DictationDemo } from "../components/DictationDemo";
import { color, font } from "../theme";

/** The core loop in a chat window: hold, speak, let go, it's there. */
export const Dictate: React.FC = () => (
  <Backdrop>
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 46 }}>
      <Caption title={<>Hold <Accent>Right ⌥</Accent>. Speak. Let go.</>} sub="It types into whatever app you're in." />
      <DictationDemo
        window="Chat"
        language="Hinglish"
        talk={[1.2, 4.2]}
        above={
          <div style={{ display: "flex", flexDirection: "column", fontFamily: font }}>
            <Bubble>Kal milna hai? 🍵</Bubble>
          </div>
        }
        text="Haan, kal 5 baje milte hain. Main Rahul ko bhi bol deta hoon."
      />
    </div>
  </Backdrop>
);

/** Per-app language: Mail gets English with no switching. */
export const PerApp: React.FC = () => (
  <Backdrop>
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 46 }}>
      <Caption title={<>Chats in Hinglish. <Accent c={color.blue}>Mail in English.</Accent></>} sub="Each app remembers its language. No switching." />
      <DictationDemo
        window="New Message"
        language="English"
        rule="Mail"
        talk={[1.0, 3.6]}
        above={
          <div style={{ fontFamily: font, fontSize: 30, color: color.dim, lineHeight: 1.9 }}>
            <div>To: Priya Sharma</div>
            <div>Subject: Thursday review</div>
          </div>
        }
        text="Hi Priya, can we move the review to Thursday at 3 pm? I'll send the deck tonight."
      />
    </div>
  </Backdrop>
);

/** Three languages, three outputs. */
export const Languages: React.FC = () => {
  const { fps } = useVideoConfig();
  const cards: [string, string, string][] = [
    ["Hinglish", "Yaar, meeting thodi late start karte hain.", color.saffron],
    ["English", "Let's start the meeting a little late.", color.blue],
    ["हिन्दी", "चलो, मीटिंग थोड़ी देर से शुरू करते हैं।", color.green],
  ];
  return (
    <Backdrop>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 70 }}>
        <Caption title="Three languages, written the way you write them." />
        <div style={{ display: "flex", gap: 40 }}>
          {cards.map(([name, line, c], i) => (
            <Sequence key={name} from={(0.6 + i * 0.4) * fps} layout="none">
              <LanguageCard name={name} line={line} c={c} />
            </Sequence>
          ))}
        </div>
      </div>
    </Backdrop>
  );
};

const LanguageCard: React.FC<{ name: string; line: string; c: string }> = ({ name, line, c }) => (
  <div
    style={{
      width: 500,
      padding: "40px 44px",
      borderRadius: 28,
      background: color.bgSoft,
      border: `2px solid ${c}`,
      fontFamily: font,
    }}
  >
    <div style={{ fontSize: 48, fontWeight: 800, color: c }}>{name}</div>
    <div style={{ marginTop: 22, fontSize: 38, lineHeight: 1.35, color: color.text }}>{line}</div>
  </div>
);
