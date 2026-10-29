/**
 * Your voice, on the three dictations where the app is seen listening: the
 * email, the ums, the Hinglish chat. The words on screen stay the script's;
 * the voice is the sound of saying them.
 *
 * Clips are public/voice/mix/<id>.wav, made by scripts/prepare-voice.sh: each
 * starts LEAD s before the speech. `at` is when the speech starts, in seconds
 * from the scene's start; `speech` is how long it lasts (the script prints it).
 */
export const TAKES = {
  mail: { at: 1.2, speech: 5.19 },
  fillers: { at: 0.5, speech: 4.66 },
  chat: { at: 1.0, speech: 3.14 },
} as const;

export type TakeId = keyof typeof TAKES;

/** Silence each clip keeps before the speech. */
export const LEAD = 0.1;

/** The key is down from just before the speech until it ends. */
export const talkFor = (id: TakeId): [number, number] => [
  TAKES[id].at - 0.2,
  TAKES[id].at + TAKES[id].speech,
];

/** When the spoken words are done, in scene seconds. */
export const spokenBy = (id: TakeId) => TAKES[id].at + TAKES[id].speech;
