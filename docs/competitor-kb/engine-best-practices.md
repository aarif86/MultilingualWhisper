# Engine Best Practices for Dictation-Quality ASR

> Research pass across speech-engine vendor docs, model-author docs, and academic/blog sources, focused on what actually moves dictation quality: vocabulary biasing, formatting/ITN, disfluency handling, endpointing/streaming, hallucination control, on-device model selection, code-switching resources, and LLM cleanup patterns.
>
> Written for **Nasar Flow**: offline whisper.cpp iOS+Android dictation for Singlish/Malay/Arabic code-switching, with a system keyboard extension; on-device whisper.cpp using converted Singlish/Malay/Arabic small models (q5_1); considering an on-device LLM cleanup pass.

---

## Vocabulary biasing (per vendor: what + limits)

### Deepgram — Keyterm Prompting (Nova-3/Flux) vs Keywords (legacy)

- **Keyterm Prompting**: `?keyterm=TERM` (repeatable), up to **500 tokens total** per request.
- Works on **Nova-3 and Flux only**, both monolingual and multilingual.
- No weight/intensifier syntax — plain terms only. Avoid commas, semicolons, weights.
- Capitalization and punctuation in the keyterm are preserved and steer output casing (e.g. brand names keep their casing; lowercase common terms).
- Docs: [Keyterm Prompting](https://developers.deepgram.com/docs/keyterm)
- **Keywords** (legacy): `keywords=WORD:INTENSIFIER`, default weight 1, negative values suppress the word.
- Max **100 keywords per request**; works only on Nova-2/Nova-1/Enhanced/Base — **not Nova-3**.
- Suppression (negative intensifier) only functions on **Base** models.
- Deepgram's own guidance: start with small intensifier values and add incrementally — "high intensifiers can cause false positives."
- Migrating keywords → keyterms means stripping weights entirely; a weighted value is "silently ignored" and the term is treated as a literal keyterm.
- Docs: [Keywords](https://developers.deepgram.com/docs/keywords)

### AssemblyAI — Keyterms Prompting + Custom Spelling

- Pre-recorded: up to **200 boosted terms/phrases** on Universal-2, up to **1000** on Universal-3.5 Pro (max 6 words/phrase).
- Streaming: `keyterms_prompt` accepts up to **100 terms**, each ≤50 characters.
- **Custom Spelling**: maps a spoken phrase (max **5 words**) to an exact output spelling/casing via a from→to dictionary — this fixes orthography, it does not change recognition probability.
- Docs: [Custom Vocabulary guide](https://docs.assemblyai.com/guides/boosting-accuracy-for-keywords-or-phrases) · [Streaming keyterms](https://www.assemblyai.com/blog/streaming-keyterms-prompting) · [Custom Spelling](https://www.assemblyai.com/docs/speech-to-text/pre-recorded-audio/custom-spelling)

### OpenAI Whisper / gpt-4o-transcribe — `prompt` (style/spelling nudge, not true biasing)

- `prompt` is capped at **224 tokens**; anything longer is **silently truncated to the last 224 tokens**.
- Whisper does not follow instructions in the prompt — it imitates the prompt's *style* (casing, punctuation conventions, spelling choices for ambiguous names), per OpenAI's own guide: "Whisper doesn't follow instructions like a general-purpose text model."
- A glossary-style prompt (e.g. "Aimee, Shawn, BBQ") nudges spelling of near-homophones but cannot invent content the model didn't hear, and works less reliably for rare/atypical styles ("if the speakers are not speaking in a deep Southern accent, a prompt will not cause the transcript to do so").
- Longer, more natural example prompts steer the model more reliably than short ones.
- gpt-4o-transcribe additionally accepts `keywords` and `languages` params alongside `prompt`, and supports `stream=true` for partial `transcript.text.delta` events (whisper-1 does not stream).
- Docs: [Whisper prompting guide](https://developers.openai.com/cookbook/examples/whisper_prompting_guide) · [Speech-to-text guide](https://developers.openai.com/api/docs/guides/speech-to-text)

### whisper.cpp — `--prompt` / `initial_prompt`

- Same **~224-token** limit as OpenAI's API (inherited from the model's decoder context window), prepended to the decoder as initial context.
- `carry_initial_prompt` (a `whisper_full_params` field) re-prepends the initial prompt to **every** decode window instead of only the first — useful for persistent vocabulary priming across a long dictation session rather than a one-shot nudge that fades after the first chunk.
- Repo: [whisper.cpp](https://github.com/ggml-org/whisper.cpp)

### Speechmatics — Custom Dictionary (`additional_vocab`)

- Up to **1000 words/phrases per job** — the most generous per-request vocabulary limit of any vendor reviewed.
- Each entry has a `content` field (canonical output spelling) and an optional `sounds_like` field (alternate pronunciation hints to aid acoustic matching, e.g. "gnocchi" or "CEO" get phonetic hints; a phrase like "financial crisis" doesn't need one).
- Docs: [Custom dictionary](https://docs.speechmatics.com/speech-to-text/features/custom-dictionary)

### Google Cloud STT — Speech Adaptation (phrase sets + boost)

- Phrase sets define single- or multi-word phrases, optionally referencing class tokens (e.g. `$OOV_CLASS_ALPHANUMERIC_SEQUENCE`).
- `boost` is a float **0–20**. At `boost=0`/unset, default biasing helps the whole phrase and its continuous sub-spans; positive boost is a stronger effect but applies only to the **exact** phrase.
- Google's explicit guidance: implement boost only after model adaptation is already in place, keep the phrase list **small**, and only add phrases recognition already struggles with.
- Trade-off stated directly in the docs: higher boost reduces false negatives but increases false positives (words appearing in the transcript that weren't actually said).
- Docs: [Model adaptation](https://docs.cloud.google.com/speech-to-text/docs/adaptation-model)

### Azure Speech — Phrase Lists

- A short, per-recognition list of expected words/phrases (not weighted, not a persistent trained model) — best for session-specific jargon: meeting attendee names, product SKUs, one-off proper nouns.
- Sits upstream of Azure's separate display-text formatting pipeline (see Formatting & ITN below) — phrase lists affect what's *recognized*, formatting affects how it's *rendered*.

### ElevenLabs Scribe

- Boosts up to **100 domain-specific terms** per request for names/jargon.
- Also does non-speech **audio-event tagging** (laughter, applause, music, background noise) so the transcript captures more than just words — relevant if Nasar Flow ever wants to distinguish "user paused to laugh" from silence.
- Docs: [Speech-to-text overview](https://elevenlabs.io/docs/overview/capabilities/speech-to-text)

### Comparative takeaway

Every cloud vendor treats vocabulary biasing as a **short, curated, per-session list** (100–1000 items), never a giant dictionary, and every one explicitly warns that large lists or high boost/intensity values raise false positives. whisper.cpp's `--prompt` is the weakest mechanism of the group — a style nudge capped at 224 tokens, easily crowded out by a long dictation. For Nasar Flow, a **user-maintained rotating glossary** (contacts, Singlish/Malay proper nouns, current app's jargon) is best implemented as (a) a short `initial_prompt` seeded with the 20–40 most contextually relevant terms, refreshed per app/contact, plus (b) a post-ASR exact-remap pass (Custom-Spelling-style) for names Whisper is known to consistently mis-hear — rather than trying to cram a comprehensive dictionary into the prompt.

---

## Formatting & ITN

### Deepgram

- **`smart_format`** bundles punctuation + paragraphs +, for English, dates/times/currency/phone numbers/emails/URLs/numerals into one flag. Non-English models get punctuation+paragraphs plus numerals for a subset of languages.
- Explicitly redundant with `punctuate=true` — "no need to also set punctuate=true" once smart_format is on.
- Streaming behavior: holds entities up to **3 seconds of silence** before finalizing formatting, or skips formatting entirely under `no_delay=true`.
- Docs: [Smart Format](https://developers.deepgram.com/docs/smart-format)
- **`dictation`** mode (English only): converts *spoken* punctuation commands ("comma", "period") into literal punctuation marks. Requires `punctuate=true` to also be set. Docs: [Dictation](https://developers.deepgram.com/docs/dictation)
- **`numerals`**: converts spoken numbers to digits ("nine hundred" → "900", "nine hundredth" → "900th"). Standalone support: 18+ languages. Under Nova-3/Flux Multilingual, only 8 languages get numerals (EN, ES, FR, DE, RU, PT, IT, NL) — notably **excluding Hindi and Japanese**.
- Caveat: numerals and punctuation don't compose cleanly — "999,999" transcribes as "999999" (no thousands separator) when both flags are active. Docs: [Numerals](https://developers.deepgram.com/docs/numerals)
- **`paragraphs`**: auto-segments into paragraphs from punctuation boundaries, plus speaker/channel changes when diarization or multichannel audio is active; auto-enables punctuation. Docs: [Paragraphs](https://developers.deepgram.com/docs/paragraphs)

### AssemblyAI

- **Custom Formatting / `disfluencies`**: Universal-2 exposes a boolean (default off — "um"/"uh"/"hm" stripped). Universal-3 Pro folds formatting style, disfluency handling, *and* code-switching behavior into one free-text `prompt` parameter — a more instructable, single-field version of what Deepgram splits across several booleans.
- Docs: [Filler Words](https://www.assemblyai.com/docs/filler-words) · [Custom Formatting](https://www.assemblyai.com/docs/speech-understanding/custom-formatting)

### Azure Speech — lexical → display-text pipeline

- Azure explicitly separates **recognition** (raw lexical text) from **display formatting**, which runs as a documented **sequence of builders**: ITN → capitalization → profanity filtering.
- ITN converts verbalized forms to symbolic ones: dates, times, decimals, currencies, addresses, emails, phone numbers.
- **Custom Display Format** lets a customer extend base ITN with rule-based patterns: a testable DSL with `#itn` sections (pattern rules) and `#test` sections (input lexical text → expected display-format output pairs) — i.e. formatting edge cases are unit-tested, not left to model behavior.
- Docs: [Display text formatting](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/display-text-format) · [Custom Display Format](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/introducing-custom-display-format-in-azure-ai-speech/3948441)

### NeMo Text Processing (NVIDIA) & WeTextProcessing (WeNet)

- Both are **WFST-based** (Weighted Finite-State Transducer) toolkits used as a *separate post-ASR stage*, decoupled from the acoustic model.
- **TN** (text normalization): written → spoken form, used mainly for TTS.
- **ITN** (inverse text normalization): spoken → written form, used for ASR output — "one hundred twenty-three" → "123".
- WeTextProcessing covers Chinese + English with rules for numbers, dates, currency, colloquialisms. NeMo-text-processing is broader/pluggable across languages, Apache-2.0.
- This is the architectural pattern whisper.cpp lacks entirely: mature stacks run a **separate, deterministic, testable ITN grammar** after the acoustic model rather than expecting the model to emit correctly formatted digits/dates/currency.
- Repos: [NeMo-text-processing](https://github.com/NVIDIA/NeMo-text-processing) · [WeTextProcessing](https://github.com/wenet-e2e/WeTextProcessing)

### Takeaway

Every mature vendor treats formatting as a **separate deterministic pass**, and every one warns about redundant or conflicting flags (smart_format vs punctuate) or format interactions that don't compose (numerals vs punctuation). whisper.cpp emits raw lexical text with **zero ITN**. Nasar Flow needs its own lightweight ITN/formatting pass (see Recommendations) tuned for Singlish/Malay number, date, and currency conventions — nothing in the stock whisper.cpp ggml pipeline covers this.

---

## Filler/disfluency handling

- **Deepgram `filler_words`** (off by default): strips exactly **two** words when off — "uh" and "um" — and normalizes spoken variants ("uhhhh") to the canonical spelling. Turning it on surfaces **five more** recognized tokens: "mhmm", "mm-mm", "uh-uh", "uh-huh", "nuh-uh". Only available on Nova/Nova-2/Nova-3 general English models. Docs: [Filler Words](https://developers.deepgram.com/docs/filler-words)
- **AssemblyAI `disfluencies`** (Universal-2, default off): same idea — "um"/"uh"/"hm" stripped unless a dedicated Disfluency Detection sub-model is turned on. Universal-3 Pro folds this into the free-text `prompt`. Docs: [Filler Words](https://www.assemblyai.com/docs/filler-words)
- **Whisper / whisper.cpp**: no dedicated disfluency toggle at all. Filler suppression has to happen via `suppress_regex`/token-level suppression at decode time, or a post-processing regex — much blunter than Deepgram/AssemblyAI's word-aware detection, and risks over-suppressing "um" in a context where it's meaningful.
- **Academic pattern**: disfluency removal and punctuation restoration are generally treated as *separate downstream NLP models* (sequence-tagging or seq2seq models trained on annotated speech transcripts), not something the acoustic decoder should solve jointly — mirroring the ITN separation above.

### Takeaway

Filler handling in the leading vendors is a **lexical toggle on a fixed short list** (2–7 words), not a general disfluency remover. Broader cleanup (repeated false starts, "I mean", self-corrections) is explicitly punted to either a dedicated disfluency model or an LLM pass. For Nasar Flow: keep a small, fast, rule-based filler list per language (English/Singlish, Malay, Arabic each need their own canonical filler set — Deepgram's 7-token English list is a reasonable starting point for English), and route anything beyond simple word-list filtering to the LLM cleanup pass rather than trying to make the wordlist smarter than it should be.

---

## Endpointing, VAD & streaming

### Deepgram — two complementary knobs

- **`endpointing`** (default **10ms**): silence-based finalization via VAD. Raise it (e.g. to 300ms) to avoid cutting off mid-thought. Set `false` to disable entirely and defer to Deepgram's own chunking algorithm.
- **`utterance_end_ms`** (default **1000ms**, valid range **1000–5000ms**): a second-order signal — analyzes the gap after the last **finalized** word (not raw audio silence), and requires `interim_results=true` to function. This answers "has the person truly stopped talking," distinct from endpointing's "can I finalize this chunk now."
- Recommended pattern: short endpointing (~300ms) for responsive finalization, longer utterance_end (~1000ms+) as the true turn-end signal, used together.
- **`interim_results`**: streams progressively-refined partial transcripts; each message carries an `is_final` flag. `is_final=true` means "max accuracy reached for this segment," **not** "user stopped talking" — that's what `utterance_end`/`speech_final` are for.
- Docs: [Endpointing](https://developers.deepgram.com/docs/endpointing) · [Utterance End](https://developers.deepgram.com/docs/utterance-end) · [Interim Results](https://developers.deepgram.com/docs/interim-results)

### AssemblyAI Universal-Streaming — semantic turn detection

- A genuinely different approach: instead of pure silence-VAD, a neural turn-detection model combines **acoustic + semantic** features (does the utterance sound grammatically/semantically complete?) with silence duration.
- `end_of_turn_confidence_threshold` (default **0.4**): raise to ~0.7 for reflective domains (healthcare, legal) where speakers pause mid-thought without meaning to yield the turn.
- `min_turn_silence` (default **400ms**): raise so a paused phone number or hesitant dictation doesn't fragment into multiple turns.
- `max_turn_silence` (default **1280ms**): the acoustic fallback — force-ends the turn regardless of confidence once silence exceeds this.
- `vad_threshold` (default **0.4**): raise in noisy environments to reduce false speech detections; lower it when quiet speech is being missed.
- Each streamed message carries `end_of_turn` (bool) and `end_of_turn_confidence` (float 0–1); the docs explicitly warn to key behavior off `end_of_turn`, **not** `turn_is_formatted`.
- Docs: [Turn Detection](https://www.assemblyai.com/docs/streaming/universal-streaming/turn-detection)

### whisper.cpp `stream` example — explicitly not production-grade

- Documented by the project itself as "a naive example," not production streaming.
- Default mode samples the mic every **0.5 seconds** and re-transcribes continuously.
- `--step 0` switches to a basic VAD sliding-window mode (`-vth` threshold, default ~0.6) that only transcribes after speech is detected, buffering the last `--length` ms.
- The docs flag the VAD here as "very basic" and explicitly invite a "more sophisticated approach" for real use.
- Repo: [stream example](https://github.com/ggml-org/whisper.cpp/blob/master/examples/stream/README.md)

### whisper.cpp Silero VAD integration — separate from the naive stream example

- `--vad` flag runs a proper Silero-VAD pass **before** Whisper decoding, skipping silence to speed up transcription and shrink the silence-hallucination surface.
- Params: `--vad-threshold` (speech-probability cutoff), `--vad-min-speech-duration-ms` (filters brief noise blips), `--vad-max-speech-duration-s` (caps segment length so VAD doesn't hand Whisper an overlong chunk), `--vad-speech-pad-ms` (pads segment boundaries so words aren't clipped at the edges).
- Models are downloaded separately: `download-vad-model.sh silero-v6.2.0`.
- Repo: [whisper.cpp](https://github.com/ggml-org/whisper.cpp)

### Picovoice Cobra VAD — a possible Silero alternative

- Claims **98.9% accuracy** — "12x more accurate than Silero and 50x more accurate than WebRTC VAD" — at **0.02% CPU**.
- If this claim holds under Nasar Flow's own testing, it's a meaningfully better on-device VAD than Silero for exactly the low-power/mobile context Nasar Flow runs in.
- Docs: [Cobra VAD](https://picovoice.ai/docs/cobra/)

### Takeaway

The two most sophisticated cloud vendors both moved past pure silence-VAD to a **two-signal model**: a fast/aggressive chunk-finalization signal plus a slower, more deliberate true-turn-end signal (semantic, for AssemblyAI). whisper.cpp's shipped streaming story sits one rung below either: naive fixed-interval or basic-VAD chunking with no semantic component and an explicit "not production-ready" disclaimer from the maintainers. For Nasar Flow's dictation UX — where "cut off my thought mid-sentence" is exactly the complaint users file against dictation apps, and code-switching pauses (searching for the Malay word) are a normal, expected pattern rather than an edge case — the practical target is: Silero (or Cobra, pending in-house validation) VAD gates *when* whisper.cpp even runs inference, with a tunable two-stage silence-then-finalize timer analogous to Deepgram's endpointing/utterance_end split, rather than the raw fixed-interval poll in the current example code.

---

## Hallucination & robustness controls (whisper-specific)

### Why Whisper hallucinates on silence/non-speech

Whisper was trained partly on YouTube audio+subtitle pairs; during low-energy or silent segments it falls back to patterns memorized from training data — stock phrases like "thank you for watching." OpenAI's own server-side mitigation for whisper-1 was to detect probable hallucination and skip/retranscribe silent periods; gpt-4o-transcribe is reported to reduce (not eliminate) this via a different underlying architecture. [Community discussion](https://community.openai.com/t/all-my-attempts-to-improve-accuracy-and-reduce-hallucinations-have-the-opposite-effect/997302)

### "Careless Whisper" (Koenecke et al., arXiv:2402.08021)

- Measured roughly **1% of transcriptions contain entirely fabricated content** not present in the source audio.
- Of those hallucinations, **38% contained explicit harm**: fabricated violence, false authority claims, invented associations.
- Critically, the rate was **not evenly distributed**: speakers with aphasia — whose speech has longer non-vocal/silent durations as a symptom — triggered disproportionately more hallucinations.
- Relevance to Nasar Flow: this failure mode correlates with halting, pause-heavy speech — exactly the pattern a dictation user thinking aloud or hunting for a code-switched word will produce.
- Paper: [arXiv:2402.08021](https://arxiv.org/abs/2402.08021)

### Non-speech-audio hallucination study (arXiv:2501.11378, ICASSP 2025)

- Systematically fed Whisper non-speech audio (background noise, music, room-tone silence) and found hallucinations cluster into a **recurring, enumerable set of phrases** rather than being random.
- Mitigation proposed: build that "bag of hallucinations" (BoH) list and filter/flag transcript segments matching it post-hoc — a cheap, model-agnostic, on-device-friendly safeguard that reduced WER in their tests.
- Paper: [arXiv:2501.11378](https://arxiv.org/abs/2501.11378)

### `whisper_full_params` knobs directly relevant to hallucination/robustness

- `no_speech_thold` (default ~**0.6**): segments whose no-speech probability exceeds this are treated as silence and dropped — the primary silence-hallucination guard.
- `entropy_thold` (default **2.40**): if the last 32 tokens' repetition-entropy falls below this (the model is looping/repeating), the decoder retries at a higher temperature — whisper.cpp's guard against the classic "repeated phrase" degenerate loop.
- `logprob_thold`: drops segments whose average token log-probability indicates low confidence.
- `temperature` + `temperature_inc`: temperature-fallback decoding — start near-greedy for stability, and only retry at increasing temperature (steps of ~0.2, up to 1.0) if entropy/logprob thresholds fail.
- `suppress_blank`: prevents emitting blank/empty tokens.
- `suppress_nst` (renamed from `suppress_non_speech_tokens`): suppresses non-speech special tokens (music/applause tags) at the logit level.
- `suppress_regex`: a user-suppliable regex over the vocabulary to ban tokens outright — directly usable to implement a manual "bag of hallucinations" filter (matching the arXiv:2501.11378 mitigation) or to ban non-target-language scripts.
- `initial_prompt` / `carry_initial_prompt`: see Vocabulary Biasing above — max ~224 tokens.
- `max_initial_ts`: bounds how far into a chunk the model's very first timestamp can land, preventing a bad first guess from skewing the whole segment.
- `token_timestamps`, `thold_pt`, `thold_ptsum`: token-level timestamp computation with probability thresholds, usable to detect/exclude low-confidence-timestamp tokens — hallucinated text often has poor timestamp alignment, making this a secondary hallucination signal.
- `dtw_token_timestamps` / `dtw_aheads_preset` / `dtw_n_top`: experimental Dynamic Time Warping-based alignment for more accurate token timestamps than the naive cross-attention approach, with per-model-size attention-head presets.
- Source: [whisper.h](https://github.com/ggml-org/whisper.cpp) (`include/whisper.h`)

### Quantization (q5_0 / q5_1 / q8_0)

- whisper.cpp's `quantize` tool produces integer-quantized ggml models, e.g. `./build/bin/quantize models/ggml-base.en.bin models/ggml-base.en-q5_0.bin q5_0`.
- Quantized models need less memory/disk and can run faster depending on hardware, at some accuracy cost.
- The README does not publish a definitive WER-vs-speed table for q5_0 vs q5_1 vs q8_0 — any accuracy claim for Nasar Flow's converted q5_1 models should be benchmarked in-house against an fp16 baseline on the actual target phones rather than assumed from general community claims.

### Core ML / Metal on Apple platforms

- Core ML lets the Whisper **encoder** run on the Apple Neural Engine, reported as **>3x faster** than CPU-only execution.
- Metal separately lets inference run on GPU.
- These are complementary, not competing: Core ML for the ANE-eligible encoder path, Metal as the GPU fallback/decoder path — the primary levers for iOS latency, more impactful than quantization level alone on devices with ANE access.
- Repo: [whisper.cpp README](https://github.com/ggml-org/whisper.cpp)

### Takeaway

whisper.cpp already exposes essentially every lever the Whisper hallucination-mitigation literature recommends (`no_speech_thold`, `entropy_thold`/`logprob_thold` + temperature fallback, `suppress_regex`). The gap is almost entirely in **whether Nasar Flow's current config actually tunes these** versus running library defaults, and whether a Silero/Cobra VAD gate runs *before* whisper.cpp sees the audio at all — the cheapest, most effective hallucination guard of all is simply not feeding the model silence. The "bag of hallucinations" regex-filter pattern is directly implementable via `suppress_regex` or a lightweight post-filter, and is a good low-effort addition given that pause-heavy, aphasia-adjacent speech is a realistic Nasar Flow usage pattern (dictating while thinking, code-switching mid-sentence).

---

## On-device model landscape for phones

| Model / engine | Size | RTF on mobile (reported) | Languages | License |
|---|---|---|---|---|
| **whisper.cpp (ggml) tiny/base/small, q5_1** — current Nasar Flow base | tiny ~39M, base ~74M, small ~244M params; q5_1 shrinks disk/RAM further | Not vendor-published; Core ML (ANE) reported ~3x+ vs CPU-only on Apple Silicon/A-series; must be benchmarked per target device | Whisper's ~99 languages (coverage varies by size for lower-resourced ones) | MIT (whisper.cpp) / MIT (OpenAI Whisper weights) |
| **Moonshine (Useful Sensors)** tiny/base, v2 streaming | tiny **27M params** | Explicitly targets severely memory/compute-constrained hardware; no absolute RTF published, but positioned as sub-Whisper-tiny footprint | English-focused (tiny/base); v2 adds a sliding-window streaming encoder for latency-critical use | Apache-2.0-style OSS (Useful Sensors HF org) |
| **Picovoice Cheetah** (streaming) / **Leopard** (offline) | Proprietary, small enough for mobile/embedded | Vendor claims "matches/exceeds cloud accuracy" with "guaranteed response time"; no independent RTF published | EN, plus FR/DE/IT/PT/ES on Cheetah | Commercial (per-device licensing) |
| **Picovoice Cobra** (VAD only, not ASR) | Tiny | 0.02% CPU, 98.9% claimed accuracy | N/A (VAD) | Commercial |
| **NVIDIA Parakeet-TDT-0.6B-v3** | 600M params | FastConformer encoder + TDT decoder; NeMo/onnx-asr position edge/CPU-only deployment as feasible at this size, but no phone-specific RTF published by NVIDIA | 25 languages, multilingual | CC-BY-4.0 (model) / Apache-2.0 (NeMo toolkit) |
| **NVIDIA Canary-1B-v2** | 1B params | Heavier; framed as server/desktop-class rather than phone-class | 25 EU languages + EN↔X speech translation | CC-BY-4.0 |
| **sherpa-onnx streaming Zipformer** (bilingual zh-en, en, zh, ko, fr variants) | **14M–20M params** — explicitly tuned for "Cortex A7 CPU"-class hardware | No published absolute RTF in the repo, but parameter count and target-CPU framing imply strong headroom on modern phone SoCs | Per-model, not unified: EN, ZH, bilingual ZH-EN, KO, FR | Apache-2.0 |
| **Kyutai STT (Delayed Streams Modeling)** — 1B (en/fr) and 2.6B (en) | 1B / 2.6B params | 1B model confirmed running on-device on an **iPhone 16 Pro** via MLX/Swift; ~0.5s delay (1B) vs ~2.5s delay (2.6B) — delay is a designed latency/accuracy trade-off, not raw RTF | EN+FR (1B model), EN-only (2.6B model) | Open weights (verify exact terms per repo) |
| **Apple SpeechAnalyzer / SpeechTranscriber (iOS 26)** | OS-managed, on-device, downloaded language assets | Not published as RTF; positioned as long-form (removes the legacy SFSpeechRecognizer 1-minute session cap) | Per iOS language-asset availability | Apple platform API (not redistributable off-Apple-OS) |
| **Mesolitica Malaysian Whisper** (base/small v2/v3/medium/large, distil-large-v3) | Same param counts as stock Whisper equivalents (fine-tuned, not shrunk) | Same runtime cost as stock Whisper of matching size | Malay (standard + local/"pasar"), English incl. Singlish/Manglish, partial Mandarin/Tamil | Model-dependent — check each Hugging Face repo |
| **MERaLiON-3-3B-ASR** (A\*STAR/I2R) | 3B params (down from 10B in MERaLiON-2, matching/beating it on every eval section) | Server/desktop-class at 3B — not a phone deployment target as-is, but its training approach and eval suite are directly relevant | SG/SEA-centric: English↔{Mandarin, Malay, Tamil, Vietnamese, Cantonese, Hokkien}, including Singlish code-switching | Open weights — check Hugging Face repo |

### Reading the table for Nasar Flow

whisper.cpp q5_1 base/small remains the right *general-purpose* choice for broad language coverage with mature iOS/Android tooling (Core ML/Metal), but three alternatives are worth an in-house bake-off against it:

1. **Moonshine** — if English-heavy sessions dominate and the 27M-param tiny/base footprint beats whisper-tiny on battery/latency.
2. **sherpa-onnx Zipformer** — if a narrower fixed language set per model (e.g. one dedicated Malay+English model) is acceptable; its 14–20M-param streaming models are explicitly sized for exactly this device class.
3. **Kyutai's 1B model** — already proven running on iPhone 16 Pro, with a purpose-built delayed-streams architecture rather than whisper.cpp's bolted-on VAD-chunking.

No vendor in this survey publishes a directly comparable phone RTF benchmark suite, so the decision needs an in-house bake-off on Nasar Flow's actual target device tier, not a comparison of vendor marketing claims.

---

## Code-switching & Singapore/Malay/Arabic resources

- **IMDA National Speech Corpus (NSC)** — the foundational Singapore English resource: ~10,000–10,600 hours from ~1,000 local speakers, split across phonetically-balanced scripted reading (3000h), topic-based scripted reading (3000h), and **spontaneous conversational data (900h)** — the conversational slice is the Singlish-relevant part for dictation-style speech. Publicly available under the Singapore Open Data License via imda.gov.sg/nationalspeechcorpus. [Building the NSC, Interspeech 2019](https://www.isca-archive.org/interspeech_2019/koh19_interspeech.pdf)

- **SEAME corpus** — ~192 hours of *spontaneous* Mandarin-English code-switching conversational/interview speech from 155–157 Singaporean/Malaysian bilingual speakers (~115 SG, the rest MY), with **82% of transcribed utterances containing intra-sentential code-switching** (mid-sentence mixing, not just alternating monolingual turns). The standard academic benchmark for SG/MY code-switch ASR research. [SEAME, Interspeech 2010](https://www.isca-archive.org/interspeech_2010/lyu10_interspeech.html)

- **A\*STAR/I2R MERaLiON-3-3B-ASR** — purpose-built for SG/SEA ASR with native English↔{Mandarin, Malay, Tamil, Vietnamese, Cantonese, Hokkien} code-switching **including Singlish**. Released May 2026, evaluated across 66 datasets spanning 12 language-domain sections. At 3B params it's roughly one-third the size of the prior MERaLiON-2-10B-ASR while matching or beating it on every eval section. This is the closest existing open model to "Singlish-native ASR" and the best reference point for achievable WER on this exact code-switching problem, even though 3B is too heavy to ship on-device today. [MERaLiON-3-3B-ASR](https://huggingface.co/MERaLiON/MERaLiON-3-3B-ASR)

- **Mesolitica Malaysian Whisper family** — fine-tunes of stock Whisper (base through large, plus a distil-large-v3) trained on 14,000 hours of filtered Malay YouTube speech plus curated mixed data (1k hrs English incl. Singlish/US English, 1k hrs Malay, 1k hrs phrase-mixed data, 2k hrs sampled Malay YouTube). Explicitly targets standard Malay + **local/"pasar" Malay** + English + **Manglish/Singlish**, with reported translation-quality gains for Malay/Manglish/Mandarin/Tamil "science context" material. This is the most directly reusable *Whisper-architecture* (hence whisper.cpp-convertible) resource for Nasar Flow's Malay+English code-switching target. [malaysian-whisper-small-v3](https://huggingface.co/mesolitica/malaysian-whisper-small-v3)

- **Contextual biasing via prompt-tuning** (arXiv:2410.18363, accepted IEEE SLT 2024; arXiv:2502.11572) — both papers fine-tune Whisper's *response to its own prompt mechanism* (rather than fine-tuning on new acoustic data) to improve rare/domain-specific vocabulary recognition in zero-shot settings. In other words: the 224-token `initial_prompt` can be made a much stronger biasing signal than it is out-of-the-box by training the model to actually attend to it — directly relevant to Nasar Flow's proper-noun/jargon problem with Singlish/Malay names that stock Whisper mishears. [2410.18363](https://arxiv.org/abs/2410.18363) · [2502.11572](https://arxiv.org/abs/2502.11572)

- **Arabic** — no Singapore-specific Arabic code-switching corpus surfaced in this pass (unsurprising: Arabic code-switching in the Nasar Flow context is more likely Arabic↔English or Arabic↔Malay for religious/liturgical vocabulary than a Singapore-dialect problem). Worth a targeted follow-up against MGB/QASR (Arabic broadcast ASR benchmarks) and any Gulf/Malay-adjacent Arabic loanword studies if Arabic accuracy becomes a specific blocker.

---

## LLM post-processing patterns (prompts, latency budgets)

- **OpenAI's own recommendation** for gpt-4o-transcribe/whisper-1 accuracy gaps: run a **text-model post-processing pass** with a system prompt listing expected product names/jargon and formatting rules, explicitly instructed to *validate corrections against the original transcript* so it fixes spelling/formatting without inventing content the speaker didn't say. This is essentially the architecture Nasar Flow is already considering — OpenAI treats it as the standard mitigation for the same hallucination/rare-vocabulary gaps documented above. [Speech-to-text guide](https://developers.openai.com/api/docs/guides/speech-to-text)

- **AssemblyAI Universal-3 Pro's free-text `prompt`** folds "formatting style + disfluency handling + code-switching behavior" into one instructable field at the ASR layer itself — a middle ground between "no cleanup" and "separate LLM pass." Worth studying as a UX pattern (one instruction covers several cleanup dimensions) even though Nasar Flow's LLM pass sits downstream of whisper.cpp rather than inside the ASR model.

- **Bag-of-hallucinations filtering** (arXiv:2501.11378) is a cheaper-than-LLM pattern: a static regex/phrase-list filter catching known Whisper hallucination strings, applicable before or instead of a full LLM pass in latency-sensitive cases.

- **Latency budgets other vendors already tolerate, as a reference ceiling**:
  - Deepgram's `smart_format` waits up to **3 seconds** of silence before finalizing formatting entities.
  - AssemblyAI's `max_turn_silence` defaults to ~**1.28 seconds** as the hard ceiling before forcing a turn end.
  - ElevenLabs Scribe v2 Realtime claims sub-**150ms** first-token latency.
  - An on-device LLM cleanup pass for Nasar Flow should target **well under 1 second** of added latency for a typical dictation utterance to feel as responsive as cloud vendors' own internal formatting-finalization delays, and should not exceed the ~1–3s window users already tolerate for "final" formatted text to settle in cloud dictation UIs.

- **Practical prompt shape for an on-device cleanup LLM**, synthesizing the above:
  1. State the target language mix explicitly (Singlish/Malay/Arabic code-switching) so the model doesn't "correct" valid code-switched words into English.
  2. Supply the same short rotating glossary used for whisper.cpp's `initial_prompt`, so both stages agree on proper-noun spelling.
  3. Instruct the model to fix punctuation/ITN/filler removal **only**, explicitly forbidding adding or removing meaning.
  4. Require the model to only rewrite what's already in the raw transcript, never introduce new claims — directly mirroring OpenAI's own hallucination-avoidance guidance for post-processing passes.

---

## Actionable recommendations for Nasar Flow

1. **Turn on and tune whisper.cpp's existing hallucination guards rather than relying on defaults.** Explicitly set `no_speech_thold` (verify it isn't left at a value too permissive for noisy mobile mic input), and confirm `entropy_thold`/`logprob_thold` + `temperature_inc` fallback are wired through the app's inference call — these map directly to the failure modes in arXiv:2402.08021 and arXiv:2501.11378.

2. **Gate whisper.cpp inference behind a real VAD, not a fixed-interval poll.** Use the bundled `--vad` Silero integration (`--vad-threshold`, `--vad-min-speech-duration-ms`, `--vad-max-speech-duration-s`, `--vad-speech-pad-ms`) instead of the naive 0.5s-poll `stream` example pattern; evaluate Picovoice Cobra as a swap-in if its claimed 98.9% accuracy / 0.02% CPU holds up in-house.

3. **Implement a `suppress_regex`-based "bag of hallucinations" filter** seeded from arXiv:2501.11378's methodology (systematically feed silence/noise clips, log recurring hallucinated phrases, ban them) — a cheap, static, on-device-friendly guard that doesn't need an LLM pass.

4. **Adopt a two-stage endpointing model** analogous to Deepgram's `endpointing`+`utterance_end_ms` or AssemblyAI's confidence+silence turn detection, rather than a single silence timer: a short (~300ms) "safe to start finalizing" timer plus a longer (~1000ms+) "user actually stopped" timer before committing to LLM cleanup / text insertion, so pauses mid-code-switch don't get chopped into fragments.

5. **Replace the single-shot `initial_prompt` with a short, rotating, context-aware glossary** (contacts, current app's likely jargon, recently-corrected words) capped near the real 224-token limit, and set `carry_initial_prompt=true` so it persists across the whole dictation session instead of only the first chunk.

6. **Add a deterministic ITN/formatting pass after whisper.cpp**, before or alongside any LLM cleanup, modeled on the NeMo-text-processing/WeTextProcessing/Azure builder-pipeline pattern (punctuation → number/date/currency ITN → capitalization), with Singlish/Malay-specific rules (Malay date/number conventions, Singdollar "$", HDB/MRT-style abbreviations) that no stock Whisper model handles correctly today.

7. **Build a small, curated filler-word list per language** (mirroring Deepgram's canonical 7-token English set: uh/um/mhmm/mm-mm/uh-uh/uh-huh/nuh-uh) for English/Singlish, Malay, and Arabic, applied as a fast lexical pass before falling back to the LLM for anything more structural (repeated false starts, self-corrections).

8. **Evaluate Mesolitica's `malaysian-whisper-small-v3` / `malaysian-distil-whisper-large-v3`** as a drop-in replacement or ensemble candidate for the current converted small model — it's the only Whisper-architecture (hence whisper.cpp-convertible) open model surveyed that's explicitly trained on Malay+Manglish/Singlish code-switching at scale (14,000 hrs Malay YouTube + curated mixed data). Re-quantize to q5_1 and A/B against the current model on real Singlish/Malay code-switch clips.

9. **Treat MERaLiON-3-3B-ASR's published WER numbers as the accuracy ceiling to benchmark against**, not a deployment target — too large for on-device today, but its 66-dataset SG/SEA-centric evaluation suite (or a subset) is the most relevant existing benchmark for validating Nasar Flow's own Singlish/Malay/Arabic accuracy claims, rather than relying on generic multilingual Whisper WER numbers that don't reflect code-switching.

10. **Prototype Moonshine tiny/base and sherpa-onnx's streaming Zipformer models as latency/battery comparators** against whisper.cpp base/small q5_1 on the actual target phone tier — both are explicitly designed for the "Cortex A7-class CPU, no GPU" end of the spectrum where whisper.cpp's Core ML/Metal paths don't help (i.e. Android), and this needs an in-house bake-off before committing further to whisper.cpp-only on Android specifically.

11. **Design the on-device LLM cleanup prompt around OpenAI's own post-processing guidance**: explicit code-switching language list, the same rotating glossary fed to whisper.cpp's `initial_prompt` (so both stages agree on spelling), a hard constraint to only reformat/declutter without adding or removing meaning, and validation against the raw transcript.

12. **Budget the LLM cleanup pass to well under 1 second of added latency**, using Deepgram's 3s smart_format hold and AssemblyAI's ~1.28s max_turn_silence as the outer bound cloud users already tolerate — an on-device pass slower than that will feel worse than cloud dictation despite being offline, eroding the main differentiator.

13. **Add token-level timestamp confidence** (`token_timestamps` + `thold_pt`/`thold_ptsum`, or the experimental DTW alignment via `dtw_token_timestamps`) as a second, orthogonal hallucination signal beyond `no_speech_thold`/`entropy_thold` — poor timestamp alignment is a documented secondary marker of hallucinated text, and could gate whether a segment goes through the LLM pass unmodified or gets flagged/re-decoded.

14. **Watch Apple's SpeechAnalyzer/SpeechTranscriber (iOS 26) and Kyutai's MLX 1B model (proven on iPhone 16 Pro)** as medium-term iOS-specific alternatives or complements to whisper.cpp. SpeechAnalyzer removes the legacy SFSpeechRecognizer 1-minute session cap and is fully on-device with OS-managed language assets (no app-side model shipping/updating burden); Kyutai's delayed-streams architecture is purpose-built for streaming rather than whisper.cpp's retrofitted VAD-chunking. Neither currently covers Nasar Flow's specific Malay/Singlish code-switching needs the way a Whisper-architecture fine-tune does, so this is a watch item, not an immediate switch.

15. **Do not attempt large vocabulary lists in whisper.cpp's prompt mechanism.** Every cloud vendor caps biasing lists in the 100–1000 item range and warns about false positives at scale; whisper.cpp's 224-token prompt is far more constrained than any of them. Keep glossaries short (20–40 active terms) and rotate them by context (current app, current contact) rather than trying to front-load a comprehensive Singlish/Malay/Arabic name dictionary into `initial_prompt`.

---

*Sources crawled (~35 total): Deepgram developer docs (8 pages: keyterm, keywords, smart-format, punctuation, paragraphs, numerals, filler-words, endpointing, utterance-end, interim-results, dictation, Nova-3 multilingual/code-switching); AssemblyAI docs (5 pages: custom vocabulary, custom spelling, turn detection, disfluencies/filler words, multilingual/code-switching); OpenAI/Whisper docs and cookbook (3 pages: speech-to-text guide, Whisper prompting guide, gpt-4o-transcribe/hallucination discussion); whisper.cpp README, `whisper.h`, and `stream` example (4 pages); Speechmatics, Google Cloud STT, Azure Speech, Picovoice (Cheetah/Leopard/Cobra), NVIDIA Parakeet/Canary, Moonshine, Apple SpeechAnalyzer, Kyutai STT, sherpa-onnx docs (11 pages); academic papers on arXiv (4: 2410.18363, 2502.11572, 2501.11378, 2402.08021); IMDA NSC, SEAME, MERaLiON, Mesolitica resources (5 pages); NeMo-text-processing and WeTextProcessing repos (2 pages).*
