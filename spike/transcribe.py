"""Transcribe a single audio file with a candidate model (via HF transformers).

Used for quick A/B listening tests before committing to a model.
Runs on Apple Silicon GPU (MPS) when available, else CPU.

Usage:
    uv run transcribe.py audio/clip01.wav --model swift
    uv run transcribe.py audio/clip01.wav --model apex
"""

from __future__ import annotations

import argparse
import time

import torch
from transformers import pipeline

from download_models import MODELS, download


def build_pipeline(model_key: str):
    """Create an ASR pipeline for the given model key (downloads if needed)."""
    local_path = download(model_key)
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    return pipeline(
        "automatic-speech-recognition",
        model=str(local_path),
        device=device,
        torch_dtype=torch.float16 if device == "mps" else torch.float32,
    )


def transcribe(pipe, audio_path: str) -> tuple[str, float]:
    """Return (text, seconds_taken) for one file."""
    start = time.perf_counter()
    # Oriserve models are trained to emit Roman Hinglish with language="en"
    result = pipe(
        audio_path,
        generate_kwargs={"task": "transcribe", "language": "en"},
        return_timestamps=False,
    )
    return result["text"].strip(), time.perf_counter() - start


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audio", help="path to wav/m4a/mp3 file")
    parser.add_argument("--model", default="swift", choices=list(MODELS))
    args = parser.parse_args()

    pipe = build_pipeline(args.model)
    text, elapsed = transcribe(pipe, args.audio)
    print(f"\n[{args.model}] ({elapsed:.2f}s)\n{text}")


if __name__ == "__main__":
    main()
