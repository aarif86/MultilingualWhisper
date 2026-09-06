#!/usr/bin/env python3
"""
Convert an Arabic Whisper fine-tune to GGML format for whisper.cpp.

Thin wrapper around whisper.cpp's own conversion script
(vendor/whisper.cpp/models/convert-h5-to-ggml.py) - see convert_singlish_model.py
for the full explanation of what that script does and why this doesn't reimplement it.

IMPORTANT - verify HF_MODEL_ID before running this (and its FALLBACK_MODEL_ID).
Hugging Face model availability and quality benchmarks drift over time; confirm
whichever repo you pick is still there and is actually a whisper-small (or
whisper-base) fine-tune before spending the bandwidth to clone and convert it -
see https://huggingface.co/models?search=whisper+arabic

Usage:
    pip install torch transformers numpy
    # requires `git` and `git-lfs` (git-lfs install) - HF repos store weights via LFS
    python3 scripts/convert_arabic_model.py
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

HF_MODEL_ID = "moayad/whisper-small-arabic"       # <-- verify this, see note above
FALLBACK_MODEL_ID = "ali2392/whisper-base-arabic"  # used if HF_MODEL_ID can't be cloned
OUTPUT_NAME = "ggml-small-arabic.bin"

REPO_ROOT = Path(__file__).resolve().parent.parent
WHISPER_CPP_DIR = REPO_ROOT / "vendor" / "whisper.cpp"
WORK_DIR = REPO_ROOT / ".model-conversion-workdir"
OPENAI_WHISPER_DIR = WORK_DIR / "openai-whisper"
OUTPUT_DIR = REPO_ROOT / "Models"


def run(cmd: list[str], cwd: Path | None = None) -> None:
    print(f"$ {' '.join(cmd)}")
    subprocess.run(cmd, cwd=cwd, check=True)


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        sys.exit(f"'{name}' is required but not on PATH. Install it and re-run.")


def clone_model(model_id: str) -> Path:
    model_dir = WORK_DIR / model_id.split("/")[-1]
    if not model_dir.exists():
        run(["git", "clone", f"https://huggingface.co/{model_id}", str(model_dir)])
    return model_dir


def main() -> None:
    require_tool("git")
    require_tool("git-lfs")

    convert_script = WHISPER_CPP_DIR / "models" / "convert-h5-to-ggml.py"
    if not convert_script.exists():
        sys.exit(
            f"Couldn't find {convert_script}. Did you run "
            "`git submodule update --init --recursive`?"
        )

    WORK_DIR.mkdir(exist_ok=True)
    OUTPUT_DIR.mkdir(exist_ok=True)

    if not OPENAI_WHISPER_DIR.exists():
        run(["git", "clone", "--depth", "1", "https://github.com/openai/whisper", str(OPENAI_WHISPER_DIR)])

    try:
        model_dir = clone_model(HF_MODEL_ID)
    except subprocess.CalledProcessError:
        print(f"\nCouldn't clone {HF_MODEL_ID} - falling back to {FALLBACK_MODEL_ID}.\n")
        model_dir = clone_model(FALLBACK_MODEL_ID)

    run([sys.executable, str(convert_script), str(model_dir), str(OPENAI_WHISPER_DIR), str(WORK_DIR)])

    converted = WORK_DIR / "ggml-model.bin"
    if not converted.exists():
        sys.exit(f"Conversion finished but {converted} wasn't produced - check the log above.")

    destination = OUTPUT_DIR / OUTPUT_NAME
    shutil.move(str(converted), str(destination))
    size_mb = destination.stat().st_size / (1024 * 1024)
    print(f"\nDone: {destination} ({size_mb:.0f} MB)")
    print("Upload this file to wherever Constants.swift's modelRemoteURLs points "
          "(a GitHub Release works well and is free up to 2GB/file), then update "
          "the checksum in Constants.modelChecksums.")


if __name__ == "__main__":
    main()
