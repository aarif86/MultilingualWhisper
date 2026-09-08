# Code-Switching ASR Research

Research into whether the Malay/Singlish/Arabic routing problem this app takes on has
already been solved, even partially — and what to do with what was found. This
follows on from `docs/voice-dictation-research.md`, which flagged this app's routing
problem as "genuinely uncharted" relative to general dictation-app best practices.

## Sourcing note

huggingface.co, arxiv.org, minitku.com, gladia.io, deepgram.com, and several other
primary sources were blocked for direct fetch in the session that produced this
research — findings below come from search-engine-indexed snippets, not first-hand
page reads, except where explicitly marked as fetched directly (the whisper.cpp header
check in Part 4). Verify exact license tags on any model card before shipping
anything derived from a source below.

## Part 1 — Existing apps in this niche

**"Minitku"** (minitku.com) is a Malaysian AI *meeting-minutes* app — records physical
meetings, produces transcripts/summaries/action items in English, Bahasa Malaysia, and
Chinese, explicitly handling mixed BM-English-Chinese conversation. A different product
category from this app (meeting transcription, not live dictation-anywhere), so not
directly competitive, but confirms real commercial demand for multilingual
code-switching ASR in this exact region. No independent pricing confirmation found.

Other apps/projects found in the SEA/Arabic multilingual space:
- **AI Singapore "Speech Lab"** (with NUS) — a code-switch ASR *research engine*
  (English/Mandarin/Singlish + dialect words), not a packaged consumer app;
  institutional, first client was the Singapore Civil Defence Force.
- **Munsit** (munsit.com) — Arabic-first STT, explicit Arabic-English code-switching,
  25+ dialect support, trained on ~30k hours of Arabic speech. Cloud-based — not
  usable for this app's fully-on-device constraint, but relevant competitive framing.
- **Speechmatics, Soniox, Gladia** — general cloud ASR platforms marketing native
  code-switching support including Arabic-English and Malay/Indonesian. Cloud,
  usage-based pricing — same on-device constraint applies.

No dedicated Singlish/Malay-specific consumer dictation app was found on the App
Store, Play Store, or Product Hunt. In this region, code-switching capability lives
mainly in research engines (AI Singapore) and open developer toolkits (see Part 2),
not a packaged SEA consumer dictation product — a real, still-open market gap.

## Part 2 — Existing free/open models and datasets

**Malay/Singlish specifically:**
- `mesolitica/finetune-whisper-small-ms-singlish-v2` (Mesolitica, Malaysia) —
  Whisper-**small** (same size class as this app's current models), explicitly
  fine-tuned on combined Malay + Singlish code-switched speech. The closest existing
  analog to two of this app's three targets. **License not confirmed** — verify the
  exact tag on the model card before any use.
- `mesolitica/malaysian-whisper-small-v2` — sibling model; card explicitly states it
  handles standard/local Malay, standard English, and Manglish. Same license caveat.
- **Malaya-Speech / Mesolitica** (github.com/mesolitica/malaya-speech) — a broader
  open-source Malaysian toolkit (RNNT, Wav2Vec2/HuBERT/BEST-RQ CTC, Whisper seq2seq
  variants) trained on Malay/Singlish/Malay-Singlish-Mandarin code-switched speech,
  claims beating Google ASR on Malay/Singlish test sets.

**Arabic-English specifically:**
- `ahmedheakl/arazn-whisper-medium`/`-small` (ArzEn-LLM project) — Whisper-**medium**,
  **MIT licensed (confirmed)**, +11.6% relative WER improvement over prior SOTA. Clean
  and ready-to-credit, but a size class up from this app's current Whisper-small
  Arabic model — a real download-size/inference-speed tradeoff.
- `IbrahimAmin/code-switched-egyptian-arabic-whisper-small` — trained on
  `MohamedRashad/arabic-english-code-switching` (12.5k clips) + FLEURS ar_eg. License
  not confirmed.
- **QwenCleo-ASR** — Qwen3-ASR-1.7B (Apache-2.0) fine-tuned for Egyptian
  Arabic + Arabic↔English code-switching. **Not Whisper architecture** — not
  whisper.cpp-loadable without a new runtime, so not directly usable here regardless
  of its license.

**Arabic-Malay: no model or dataset of any kind was found anywhere.** A confirmed
genuine gap in the open-source ecosystem, not a research miss — nobody has published
work on this specific pair.

**Broader Singapore/Malaysia multilingual corpora and models:**
- **IMDA National Speech Corpus Part 4** / its **MNSC re-release**
  (github.com/AudioLLMs/Singlish) — itself explicitly a Malay/Mandarin/Tamil↔English
  code-switching corpus (not just monolingual Singlish), Singapore Open Data Licence
  (free, commercial use permitted). Likely richer code-switch coverage than whatever
  subset this app's current `jensenlwt` Singlish model was tuned on — a concrete,
  low-effort future data lever.
- **SEAME** (Mandarin-English, SG/MY speakers, 192 hrs) — the best-studied SG/MY
  code-switch pair, but LDC-gated/paid (LDC2015S04), not free. Confirms Malay-English
  is comparatively under-resourced next to Mandarin-English in the research community.
- **MERaLiON** (A\*STAR I2R + IMDA) and **Polyglot-Lion** (ACL 2026) — both cover this
  region's code-switching well, but both pair a Whisper-style encoder with an LLM
  decoder (Qwen3/SEA-LION/Gemma2), multi-billion parameters — not whisper.cpp-loadable
  and too heavy for on-device iOS regardless of license.

## Part 3 — Why routing between models is the weaker architecture

Independent sources converge on the same point: production code-switching ASR has
moved from **cascade** ("route to one of several monolingual models via a separate
language-ID step" — this app's current design) toward **unified/joint models**,
because cascades lose accuracy exactly at intra-sentence language switches.

- Deepgram's own production-architecture writeup: unified multilingual models are
  "the only stable option... that holds up under real-world usage"; cascades "serve
  narrow cases where accuracy for one dominant language matters more than
  responsiveness or code-switching stability."
- Gladia: LID-then-route pipelines "add compounding latency and cut words mid-switch."
- Academically: NVIDIA's Concatenated Tokenizer (arXiv:2306.08753) gives one model
  non-overlapping per-language token ranges (implicit per-token LID) while reusing
  existing monolingual tokenizers — SOTA on the Miami Bangor code-switch benchmark,
  98%+ LID accuracy, and the basis of NVIDIA's Canary/Parakeet multilingual line.
  Amazon's joint RNN-T ASR+LID work cut WER 6.4–9.2% and LID error 54–56% versus
  separate monolingual-ASR+LID baselines, while cutting memory ~46%. A 2025
  systematic literature review of end-to-end code-switching ASR frames "two separate
  monolingual ASR systems + a frame-level LID model" as the field's earliest baseline
  architecture, explicitly superseded by joint models.

**This app's current design is a cascade variant one step further removed**: it
classifies already-*transcribed text* (`RuleBasedLanguageClassifier`), not audio, so a
mistranscribed non-dominant-language segment can itself corrupt the routing decision —
on top of paying for two full transcription passes on every "auto-detect" recording.

**Whisper's own language-token mechanism**: trained to expect exactly one language tag
per utterance, but Peng et al. (arXiv:2305.11095) found *concatenating two* language
tokens in the prompt (e.g. `<|zh|><|en|>`) measurably improves code-switched
transcription anyway, "despite Whisper never being trained to take two language
tokens." Follow-on work (arXiv:2412.16507, arXiv:2506.21576, the latter evaluated on
SEAME) adds language-aware decoder adapters or soft-prompt tuning on top for further
gains.

## Part 4 — What whisper.cpp actually exposes (fetched directly, not search-indexed)

whisper.cpp itself has no built-in code-switch mode: its own GitHub discussion
[#598](https://github.com/ggml-org/whisper.cpp/discussions/598) confirms garbled
output on mid-utterance language mixing, and the only known community workaround is
seeding a bilingual text prompt (e.g. "Hello 你好") — i.e. the same `initial_prompt`
mechanism already sitting in this codebase, disabled pending the regression
investigation in commit `c0a5c43`. Whether that mechanism is safe on this app's
converted models is a separate, still-open question either way.

`include/whisper.h` and `build-xcframework.sh` were fetched directly from
`ggml-org/whisper.cpp` at this repo's exact pinned submodule commit
(`52a939a2a762224e255d366c1182b2af4dd1a032`) to answer one concrete question: can this
app call whisper.cpp's *native audio-based* language detection instead of relying
purely on text classification? Confirmed:

```c
WHISPER_API int whisper_lang_auto_detect(
        struct whisper_context * ctx, int offset_ms, int n_threads, float * lang_probs);
```

is declared, unrestricted, and the xcframework build copies the complete unmodified
header with `export *` in its module map — no pruning, so this is genuinely callable
from Swift today, the same way every other `whisper_*` call already used in
`WhisperEngine.swift` is. It needs mel-spectrogram state already computed on the
context (`whisper_pcm_to_mel`/`whisper_set_mel` first) rather than taking raw samples
directly like `whisper_full` does internally — see the implementation in
`WhisperEngine.detectLanguageProbabilities` and its use in `WhisperService` as a fast
Arabic/non-Arabic pre-check (this app's next build; separate branch from the rest of
this work, since it touches the native decode path).

One real limit worth stating plainly: whisper.cpp's LID operates at Whisper's own
granularity, which has no concept of "Singlish" versus standard English — it can only
meaningfully help the **Arabic vs. non-Arabic** routing decision, not the finer
Malay/Singlish/Mixed labeling `RuleBasedLanguageClassifier` already does well. That
classifier stays exactly as-is for the "which languages are mixed" display badge.

## Part 5 — Recommendation

No ready-made free model already solves Arabic+Malay+English or Arabic+Malay jointly —
that gap is real and unaddressed, so there is no drop-in full replacement today.
Concrete, license-clean, whisper.cpp-compatible next steps, in order of how
low-risk they are:

1. **Ship the native audio-based Arabic/non-Arabic pre-check** (Part 4) — this app's
   immediate next build, cutting the double-transcribe cost and the
   classify-already-wrong-text failure mode for the one case audio-based LID actually
   helps. Needs real on-device verification before merge (native decode path).
2. **Evaluate `mesolitica/finetune-whisper-small-ms-singlish-v2`** as a
   replacement/merge-candidate for the Malay-English side — same Whisper-small
   architecture (GGML-convertible), already documented to handle Manglish
   code-switching. Confirm the exact license tag on the card first.
3. **For Arabic**, `ahmedheakl/arazn-whisper-medium` (MIT, +11.6% WER over prior SOTA)
   is the cleanest ready-to-credit open alternative/supplement to the current
   `oddadmix` fine-tune — validate against real audio before replacing anything in
   production (same practice this repo's README already documents for any model swap).
4. **Fine-tune further on IMDA NSC Part 4 / the MNSC re-release** — genuine
   Malay↔English code-switching data (not Singlish-only), free under the Singapore
   Open Data Licence, staying in Whisper architecture throughout.

Items 2–4 are real follow-up work, not this build — they need on-device WER
validation against real audio (and, for Mesolitica, license confirmation) before
anything derived from them should reach TestFlight users.
