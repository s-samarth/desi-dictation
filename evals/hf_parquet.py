"""Read only what we need from Hugging Face Parquet datasets.

Why not `datasets.load_dataset(streaming=True)`: it walks rows in file order,
so "the first N rows" means a handful of speakers — the opposite of the
diversity the evals need. And a naive pyarrow read over HfFileSystem
pre-buffers whole column chunks: reading four *text* columns of EdAcc pulled
2.25 GB. Here every read is an exact HTTP byte range:

  scan()  -> metadata columns only (~2 MB per 470 MB file)
  fetch() -> one row group's columns (~100 clips), only for groups we chose

Nothing is cached to disk; the selected clips are written by the caller.
"""

from __future__ import annotations

import io
import threading
import time
from concurrent.futures import ThreadPoolExecutor

import numpy as np
import pyarrow.parquet as pq
import requests
import soundfile as sf

HF = "https://huggingface.co"
_local = threading.local()


def _session() -> requests.Session:
    """One session per thread — requests.Session isn't thread-safe."""
    if not hasattr(_local, "session"):
        _local.session = requests.Session()
    return _local.session


def _get(url: str, **kwargs) -> requests.Response:
    """GET with retries: the CDN occasionally drops a range mid-transfer."""
    for attempt in range(4):
        try:
            response = _session().get(url, timeout=120, **kwargs)
            response.raise_for_status()
            return response
        except requests.RequestException:
            if attempt == 3:
                raise
            time.sleep(2 ** attempt)


class _RangeFile(io.RawIOBase):
    """Seekable read-only file over HTTP range requests."""

    def __init__(self, url: str) -> None:
        head = _session().head(url, allow_redirects=True, timeout=60)
        head.raise_for_status()
        self.url, self.size, self.pos = head.url, int(head.headers["Content-Length"]), 0

    def seekable(self) -> bool:
        return True

    def readable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.pos

    def seek(self, offset: int, whence: int = 0) -> int:
        self.pos = {0: offset, 1: self.pos + offset, 2: self.size + offset}[whence]
        return self.pos

    def readinto(self, buffer) -> int:
        n = min(len(buffer), self.size - self.pos)
        if n <= 0:
            return 0
        rng = {"Range": f"bytes={self.pos}-{self.pos + n - 1}"}
        data = _get(self.url, headers=rng).content
        buffer[:len(data)] = data
        self.pos += len(data)
        return len(data)


def _open(repo: str, path: str) -> pq.ParquetFile:
    url = f"{HF}/datasets/{repo}/resolve/main/{path}"
    return pq.ParquetFile(io.BufferedReader(_RangeFile(url), 1 << 18), pre_buffer=False)


def list_files(repo: str, prefix: str, contains: str = "") -> list[str]:
    """Parquet paths under `prefix` whose name contains `contains`."""
    url = f"{HF}/api/datasets/{repo}/tree/main/{prefix}?recursive=true"
    tree = _get(url).json()
    return sorted(e["path"] for e in tree
                  if e["path"].endswith(".parquet") and contains in e["path"])


def scan(repo: str, files: list[str], columns: list[str]) -> list[dict]:
    """Metadata rows, each tagged with its location (_file, _rg, _i)."""
    def one(path: str) -> list[dict]:
        pf, rows = _open(repo, path), []
        for rg in range(pf.metadata.num_row_groups):
            table = pf.read_row_group(rg, columns=columns).to_pylist()
            rows += [{**r, "_file": path, "_rg": rg, "_i": i} for i, r in enumerate(table)]
        return rows

    with ThreadPoolExecutor(max_workers=6) as pool:
        return [row for part in pool.map(one, files) for row in part]


def fetch(repo: str, path: str, rg: int, columns: list[str]) -> list[dict]:
    """All rows of one row group (the unit of audio download)."""
    return _open(repo, path).read_row_group(rg, columns=columns).to_pylist()


def seconds_of(value) -> float | None:
    """Duration from the audio header alone (no decode) — word-count guesses
    under-count conversational pauses by 2-3x."""
    if isinstance(value, dict) and value.get("bytes"):
        try:
            return sf.info(io.BytesIO(value["bytes"])).duration
        except Exception:
            return None
    return None


def resample(x: np.ndarray, sr: int, target: int = 16000) -> np.ndarray:
    """Band-limited FFT resample (whole clip) — no scipy/soxr dependency."""
    if sr == target:
        return x.astype(np.float32)
    n = int(round(len(x) * target / sr))
    spec = np.fft.rfft(x)
    keep = min(len(spec), n // 2 + 1)
    out = np.fft.irfft(spec[:keep], n) * (n / len(x))
    return out.astype(np.float32)


def decode(value, sr: int | None = None) -> np.ndarray:
    """Audio cell -> 16 kHz mono float32. Handles {bytes: ...} and raw arrays."""
    if isinstance(value, dict) and value.get("bytes"):
        audio, sr = sf.read(io.BytesIO(value["bytes"]), dtype="float32")
    elif isinstance(value, dict) and value.get("array") is not None:
        audio, sr = np.asarray(value["array"], dtype=np.float32), value["sampling_rate"]
    else:
        audio = np.asarray(value, dtype=np.float32)
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    return resample(audio, int(sr or 16000))
