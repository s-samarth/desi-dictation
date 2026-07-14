// Desi Dictation demo — mic capture + API glue. Plain JS, no build step.
// Flow: tap mic → MediaRecorder → tap again → POST blob → transcript card
//       → optional AI chips (translate/organize) → second card.
const $ = (id) => document.getElementById(id);
const mic = $("mic"), hint = $("hint");
let lang = "english";
let recorder = null, chunks = [], timerId = null, startedAt = 0;
let health = { asr: true, hindi: true, ai: true };

// ── language pills ──────────────────────────────────────────────
document.querySelectorAll(".pill").forEach((pill) =>
  pill.addEventListener("click", () => {
    document.querySelector(".pill.active")?.classList.remove("active");
    pill.classList.add("active");
    lang = pill.dataset.lang;
    if (lang === "hindi" && !health.hindi) setHint("हिन्दी isn’t on this demo host — English/Hinglish work!", true);
    else setHint("tap to speak");
  }));

function setHint(text, isError = false) {
  hint.textContent = text;
  hint.classList.toggle("err", isError);
}

// ── recording ───────────────────────────────────────────────────
mic.addEventListener("click", () => (recorder ? stop() : start()));

async function start() {
  let stream;
  try {
    stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  } catch {
    return setHint("Mic permission needed — check the address-bar icon.", true);
  }
  chunks = [];
  const mime = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
    ? "audio/webm;codecs=opus" : "";       // Safari falls back to its default (mp4)
  recorder = new MediaRecorder(stream, mime ? { mimeType: mime } : {});
  recorder.ondataavailable = (e) => e.data.size && chunks.push(e.data);
  recorder.onstop = () => {
    stream.getTracks().forEach((t) => t.stop());
    send(new Blob(chunks, { type: recorder.mimeType || "audio/webm" }));
  };
  recorder.start();
  mic.classList.add("rec");
  startedAt = Date.now();
  timerId = setInterval(() => {
    const s = Math.floor((Date.now() - startedAt) / 1000);
    setHint(`listening… ${s}s — tap to finish`);
    if (s >= 60) stop();                    // demo cap
  }, 250);
  setHint("listening… tap to finish");
}

function stop() {
  clearInterval(timerId);
  mic.classList.remove("rec");
  recorder?.stop();
  recorder = null;
  setHint("transcribing…");
}

// ── API ─────────────────────────────────────────────────────────
async function send(blob) {
  const form = new FormData();
  form.append("audio", blob, "clip");
  form.append("lang", lang);
  try {
    const res = await fetch("/api/transcribe", { method: "POST", body: form });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || "try again?");
    if (!data.text) return setHint("Couldn’t hear anything — try once more, thoda paas se.", true);
    showTranscript(data.text);
    setHint("tap to speak again");
  } catch (err) {
    setHint(err.message, true);
  }
}

function showTranscript(text) {
  $("result").hidden = false;
  $("aiCard").hidden = true;
  $("transcript").textContent = text;
  $("transcriptTag").textContent = { english: "english", hinglish: "hinglish", hindi: "हिन्दी" }[lang];
  $("result").scrollIntoView({ behavior: "smooth", block: "nearest" });
}

// AI chips — transcript is editable, so fixes flow into the AI action.
document.querySelectorAll(".actions .chip").forEach((chip) =>
  chip.addEventListener("click", async () => {
    const text = $("transcript").textContent.trim();
    if (!text || chip.disabled) return;
    chip.classList.add("busy");
    const label = chip.textContent;
    chip.textContent = "working…";
    try {
      const res = await fetch("/api/refine", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text, action: chip.dataset.action }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || "AI failed — your text is untouched.");
      $("aiCard").hidden = false;
      $("aiText").textContent = data.text;
      $("aiTag").textContent = { english: "english ✨", hindi: "हिन्दी", structure: "organized" }[chip.dataset.action];
      $("aiCard").scrollIntoView({ behavior: "smooth", block: "nearest" });
    } catch (err) {
      setHint(err.message, true);
    } finally {
      chip.classList.remove("busy");
      chip.textContent = label;
    }
  }));

// copy buttons
function wireCopy(buttonId, sourceId) {
  $(buttonId).addEventListener("click", async () => {
    await navigator.clipboard.writeText($(sourceId).textContent);
    $(buttonId).textContent = "copied ✓";
    setTimeout(() => ($(buttonId).textContent = "copy"), 1200);
  });
}
wireCopy("copyTranscript", "transcript");
wireCopy("copyAI", "aiText");

// ── adapt UI to what this host actually runs ────────────────────
(async () => {
  try {
    health = await (await fetch("/api/health")).json();
  } catch { /* keep optimistic defaults */ }
  if (!health.ai) {
    document.querySelectorAll(".actions .chip").forEach((c) => (c.disabled = true));
    $("aiNote").hidden = false;
  }
})();
