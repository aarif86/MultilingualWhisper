#!/usr/bin/env python3
"""
Convert a Malay Whisper fine-tune to GGML format for whisper.cpp.

Thin wrapper around whisper.cpp's own conversion script
(vendor/whisper.cpp/models/convert-h5-to-ggml.py) - see convert_singlish_model.py
for the full explanation of what that script does and why this doesn't reimplement it.

Verified 2026-09-07: "mesolitica/malaysian-whisper-small-v2" is a real, actively
maintained whisper-small fine-tune (0.2B params, matching this app's other
models' size class) from Mesolitica/malaysia-ai - a credible, established
Malaysian speech-tech org (MIT-licensed malaya-speech toolkit, 291 GitHub
stars, Nvidia/KeyReply-sponsored). Trained on IMDA STT (the same corpus family
the Singlish model came from), a Malay Conversational Speech Corpus, and
Malaysian YouTube/audiobook data - explicitly covers "standard malay and local
malay" plus "standard english and manglish", matching this app's "everyday
Bahasa, not just formal Malay" positioning. Ships vocab.json/added_tokens.json
natively (unlike the Singlish source, which needed those regenerated).
Caveat: the HF model card carries no explicit license tag for the weights
themselves (only the surrounding toolkit is MIT) - known and accepted, not
blocking, but worth remembering if this ever needs re-litigating.
"mesolitica/malaysian-whisper-small" (no "-v2") is the same repo under an
older name - HF redirects it to -v2, so -v2 is used directly here.

This model's weights are stored as bfloat16 (unlike the Singlish/Arabic
sources, which were float32/float16) - whisper.cpp's convert-h5-to-ggml.py
calls `.numpy()` directly on each tensor, and NumPy has no bfloat16 type, so
it fails with `TypeError: Got unsupported ScalarType BFloat16` (confirmed by
actually running it, not guessed). Fixed by loading the model once in
Transformers with torch_dtype=float32 and re-saving over the cloned copy
before handing it to whisper.cpp's script - the *.json tokenizer/config files
are untouched, only the weights file gets rewritten.

Usage:
    pip install torch transformers numpy
    # requires `git` and `git-lfs` (git-lfs install) - HF repos store weights via LFS
    python3 scripts/convert_malay_model.py
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

HF_MODEL_ID = "mesolitica/malaysian-whisper-small-v2"
OUTPUT_NAME = "ggml-small-malay.bin"

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


def upcast_to_float32(model_dir: Path) -> None:
    """This model's weights are bfloat16, which NumPy can't represent - see the
    module docstring. Re-saving in float32 over the cloned copy fixes it.
    Deliberately unconditional (not "skip if already float32") - transformers'
    from_pretrained default dtype behavior isn't something to bet on guessing
    correctly, and re-running this when it's already float32 just costs a
    redundant save, not correctness, for a one-shot conversion script."""
    import torch
    from transformers import WhisperForConditionalGeneration

    model = WhisperForConditionalGeneration.from_pretrained(str(model_dir), torch_dtype=torch.float32)
    print(f"Re-saving weights as {model.dtype}...")
    model.save_pretrained(str(model_dir))


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

    upcast_to_float32(HF_MODEL_DIR)

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
