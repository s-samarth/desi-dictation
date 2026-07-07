"""Download candidate ASR models from Hugging Face for evaluation/conversion.

Usage:
    uv run download_models.py swift          # 72M  — free-tier candidate (fast)
    uv run download_models.py prime          # 0.8B — turbo-class Hinglish
    uv run download_models.py apex           # 0.8B — best Hinglish (Pro candidate)
    uv run download_models.py --list
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from huggingface_hub import snapshot_download

CACHE_DIR = Path(__file__).parent / "hf_cache"

MODELS: dict[str, str] = {
    # Hinglish fine-tunes (Apache 2.0) — output Roman-script Hinglish
    "swift": "Oriserve/Whisper-Hindi2Hinglish-Swift",
    "prime": "Oriserve/Whisper-Hindi2Hinglish-Prime",
    "apex": "Oriserve/Whisper-Hindi2Hinglish-Apex",
}


def download(name: str) -> Path:
    """Download a model snapshot and return its local path."""
    repo_id = MODELS[name]
    print(f"==> Downloading {repo_id} ...")
    path = snapshot_download(
        repo_id=repo_id,
        cache_dir=str(CACHE_DIR),
        # weights + config + tokenizer only; skip .msgpack/.h5 duplicates
        allow_patterns=["*.json", "*.txt", "*.safetensors", "*.bin", "*.model"],
    )
    print(f"==> Done: {path}")
    return Path(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model", nargs="?", choices=list(MODELS), help="model to download")
    parser.add_argument("--list", action="store_true", help="list available models")
    args = parser.parse_args()

    if args.list or not args.model:
        for key, repo in MODELS.items():
            print(f"{key:8s} -> {repo}")
        sys.exit(0)

    download(args.model)


if __name__ == "__main__":
    main()
