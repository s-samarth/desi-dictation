// Desi Dictation demo — mic capture + API glue. Plain JS, no build step.
// Flow: tap mic → MediaRecorder → tap again → POST blob → text types out
//       into the editable box → optional AI chips (translate/organize).
const $ = (id) => document.getElementById(id);
const mic = $("mic"), hint = $("hint"), box = $("box");
let lang = "english";
let recorder = null, chunks = [], timerId = null, startedAt = 0, typerId = null;
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
  // Capture NOW — by the time onstop fires, the `recorder` global is null
  // again and reading recorder.mimeType there throws (BUILD_LOG FM#18: the
  // silent "transcribing… forever" bug).
  const blobType = recorder.mimeType || "audio/webm";
  recorder.ondataavailable = (e) => e.data.size && chunks.push(e.data);
  recorder.onstop = () => {
    stream.getTracks().forEach((t) => t.stop());
    send(new Blob(chunks, { type: blobType }));
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
  mic.disabled = true;                      // one clip at a time
  recorder?.stop();
  recorder = null;
  setHint("transcribing…");
}

// ── API ─────────────────────────────────────────────────────────
async function send(blob) {
  try {
    const form = new FormData();
    form.append("audio", blob, "clip");
    form.append("lang", lang);
    const res = await fetch("/api/transcribe", { method: "POST", body: form });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || "try again?");
    if (!data.text) throw new Error("Couldn’t hear anything — try once more, thoda paas se.");
    typeInto(data.text);
    setHint("tap to speak again — or edit the text");
  } catch (err) {
    setHint(err.message, true);
  } finally {
    mic.disabled = false;
  }
}

// Types the transcript out character by character; repeat dictations append.
function typeInto(text) {
  clearInterval(typerId);
  const prefix = box.value.trim() ? box.value.replace(/\s+$/, "") + " " : "";
  let i = 0;
  box.focus();
  typerId = setInterval(() => {
    i = Math.min(i + 2, text.length);       // 2 chars/tick ≈ 130 chars/s
    box.value = prefix + text.slice(0, i);
    box.scrollTop = box.scrollHeight;
    if (i >= text.length) clearInterval(typerId);
  }, 15);
}

$("clearBox").addEventListener("click", () => { box.value = ""; $("aiCard").hidden = true; box.focus(); });

// AI chips — the box is editable, so fixes flow into the AI action.
document.querySelectorAll(".actions .chip").forEach((chip) =>
  chip.addEventListener("click", async () => {
    const text = box.value.trim();
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
function wireCopy(buttonId, getText) {
  $(buttonId).addEventListener("click", async () => {
    await navigator.clipboard.writeText(getText());
    $(buttonId).textContent = "copied ✓";
    setTimeout(() => ($(buttonId).textContent = "copy"), 1200);
  });
}
wireCopy("copyBox", () => box.value);
wireCopy("copyAI", () => $("aiText").textContent);

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
