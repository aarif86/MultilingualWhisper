#!/usr/bin/env python3
"""
Convert the Singlish Whisper fine-tune to GGML format for whisper.cpp.

This is a thin wrapper around whisper.cpp's own conversion script
(vendor/whisper.cpp/models/convert-h5-to-ggml.py) - it does the real work of
mapping HF transformers weight names to whisper.cpp's GGML layout, and is
tracked as part of the whisper.cpp submodule rather than reimplemented here.

IMPORTANT - verify HF_MODEL_ID before running this. Multiple "Singlish Whisper"
fine-tunes exist on Hugging Face under different namespaces (this app's original
spec named "ivabojic/whisper-small-singlish-122k"; at the time this script was
written, a model with the same name/training-set description was also found
published as "jensenlwt/whisper-small-singlish-122k"). Check
https://huggingface.co/models?search=whisper-small-singlish and confirm which
repo you actually want before spending the time/bandwidth to convert it -
these checkpoints are ~1GB+ to clone.

Usage:
    pip install torch transformers numpy
    # requires `git` and `git-lfs` (git-lfs install) - HF repos store weights via LFS
    python3 scripts/convert_singlish_model.py
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

HF_MODEL_ID = "ivabojic/whisper-small-singlish-122k"  # <-- verify this, see note above
OUTPUT_NAME = "ggml-small-singlish.bin"

REPO_ROOT = Path(__file__).resolve().parent.parent
WHISPER_CPP_DIR = REPO_ROOT / "vendor" / "whisper.cpp"
WORK_DIR = REPO_ROOT / ".model-conversion-workdir"
OPENAI_WHISPER_DIR = WORK_DIR / "openai-whisper"
HF_MODEL_DIR = WORK_DIR / HF_MODEL_ID.split("/")[-1]
OUTPUT_DIR = REPO_ROOT / "Models"


def run(cmd: list[str], cwd: Path | None = None) -> None:
    print(f"$ {' '.join(cmd)}")
    subprocess.run(cmd, cwd=cwd, check=True)


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        sys.exit(f"'{name}' is required but not on PATH. Install it and re-run.")


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

    if not HF_MODEL_DIR.exists():
        run(["git", "clone", f"https://huggingface.co/{HF_MODEL_ID}", str(HF_MODEL_DIR)])

    run([sys.executable, str(convert_script), str(HF_MODEL_DIR), str(OPENAI_WHISPER_DIR), str(WORK_DIR)])

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
