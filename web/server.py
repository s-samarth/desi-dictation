"""Desi Dictation web demo — thin FastAPI gateway.

Architecture (deliberately boring):
  browser mic (MediaRecorder) → POST /api/transcribe (webm/mp4 blob)
    → ffmpeg → 16 kHz mono wav → whisper-server (vendored whisper.cpp,
      Apex model resident on :8081; Vaani for Devanagari on :8082 if present)
  POST /api/refine → local Ollama with the SAME prompts + Hindi-number
    prepass the Mac app ships (ported in prompts.py / hindi_numbers.py).

Completely separate from the Mac app; shares only the model files on disk.
Audio is held in temp files for the duration of one request and deleted.
"""
import asyncio, json, os, subprocess, tempfile, time
from collections import defaultdict, deque
from pathlib import Path

import httpx
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

import prompts
from hindi_numbers import normalize as hindi_numbers

ASR_EN = os.environ.get("DESI_ASR_EN", "http://127.0.0.1:8081")   # Apex
ASR_HI = os.environ.get("DESI_ASR_HI", "http://127.0.0.1:8082")   # Vaani
OLLAMA = os.environ.get("DESI_OLLAMA", "http://127.0.0.1:11434")
LLM_MODEL = os.environ.get("DESI_LLM", "gemma3:4b")
MAX_SECONDS = 60          # demo cap per clip
MAX_BYTES = 12_000_000
RATE_LIMIT = 30           # requests / 5 min / IP — demo abuse guard

app = FastAPI(title="Desi Dictation demo")
_hits: dict[str, deque] = defaultdict(deque)


def rate_limit(request: Request) -> None:
    ip = request.client.host if request.client else "?"
    window = _hits[ip]
    now = time.time()
    while window and now - window[0] > 300:
        window.popleft()
    if len(window) >= RATE_LIMIT:
        raise HTTPException(429, "Thoda ruk jao — too many requests. Try in a few minutes.")
    window.append(now)


@app.get("/")
def index():
    return FileResponse(Path(__file__).parent / "static" / "index.html")


@app.get("/api/health")
async def health():
    """The UI adapts to what this host actually has running."""
    async with httpx.AsyncClient(timeout=2) as client:
        async def up(url: str) -> bool:
            try:
                return (await client.get(url)).status_code < 500
            except Exception:
                return False
        asr_en, asr_hi = await up(ASR_EN + "/"), await up(ASR_HI + "/")
        ai = False
        try:
            tags = (await client.get(OLLAMA + "/api/tags")).json()
            ai = any(m["name"].startswith(LLM_MODEL) for m in tags.get("models", []))
        except Exception:
            pass
    return {"asr": asr_en, "hindi": asr_hi, "ai": ai}


@app.post("/api/transcribe")
async def transcribe(request: Request, audio: UploadFile = File(...),
                     lang: str = Form("english")):
    rate_limit(request)
    blob = await audio.read()
    if len(blob) > MAX_BYTES:
        raise HTTPException(413, "Clip too long for the demo (keep it under a minute).")

    # Browser containers vary (webm/opus on Chrome, mp4 on Safari) —
    # ffmpeg normalizes everything to what whisper expects.
    with tempfile.TemporaryDirectory() as tmp:
        src, wav = Path(tmp) / "in.bin", Path(tmp) / "in.wav"
        src.write_bytes(blob)
        # async subprocess — a blocking subprocess.run here would stall the
        # whole event loop (every other visitor's request) for its duration.
        proc = await asyncio.create_subprocess_exec(
            "ffmpeg", "-y", "-i", str(src), "-t", str(MAX_SECONDS),
            "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", str(wav),
            stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
        try:
            await asyncio.wait_for(proc.wait(), timeout=30)
        except asyncio.TimeoutError:
            proc.kill()
            raise HTTPException(400, "Couldn't read that audio — try again?")
        if proc.returncode != 0 or not wav.exists():
            raise HTTPException(400, "Couldn't read that audio — try again?")

        base = ASR_HI if lang == "hindi" else ASR_EN
        data = {"language": "hi" if lang == "hindi" else "en",
                "response_format": "json", "temperature": "0.0"}
        async with httpx.AsyncClient(timeout=90) as client:
            try:
                r = await client.post(base + "/inference", data=data,
                                      files={"file": ("in.wav", wav.read_bytes(), "audio/wav")})
            except Exception:
                raise HTTPException(503, "Transcription engine is warming up — try again in a moment.")
    if r.status_code != 200:
        raise HTTPException(502, "Transcription failed — try again?")
    # whisper-server puts "\n" between segments, sometimes MID-WORD
    # ("log\non" = logon). Whisper tokens carry their own leading spaces, so
    # deleting the newlines rejoins words correctly and keeps word gaps.
    text = (r.json().get("text") or "").replace("\n", "").strip()
    text = " ".join(text.split())
    return {"text": text}


@app.post("/api/refine")
async def refine(request: Request, payload: dict):
    """AI actions on a transcript: english | hindi | structure."""
    rate_limit(request)
    text = (payload.get("text") or "").strip()
    action = payload.get("action", "english")
    if not text:
        raise HTTPException(400, "Nothing to work with.")
    if action in ("english", "hindi"):
        system = prompts.TRANSLATE_EN if action == "english" else prompts.TRANSLATE_HI
        user = hindi_numbers(text)          # digits before the LLM, same as the app
    elif action == "structure":
        system, user = prompts.STRUCTURE_NOTES, hindi_numbers(text)
    else:
        raise HTTPException(400, "Unknown action.")

    body = {"model": LLM_MODEL, "stream": False, "think": False,
            "messages": [{"role": "system", "content": system},
                         {"role": "user", "content": user}],
            "options": {"temperature": 0.2}}
    async with httpx.AsyncClient(timeout=60) as client:
        try:
            r = await client.post(OLLAMA + "/api/chat", json=body)
        except Exception:
            raise HTTPException(503, "AI isn't available on this demo host right now.")
    if r.status_code != 200:
        raise HTTPException(502, "AI request failed.")
    out = (r.json().get("message", {}).get("content") or "").strip()
    if "</think>" in out:
        out = out.split("</think>")[-1].strip()
    if not out:
        raise HTTPException(502, "AI returned nothing — original text is untouched.")
    return {"text": out}


app.mount("/", StaticFiles(directory=Path(__file__).parent / "static"), name="static")
