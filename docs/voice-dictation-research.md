# Nasar Flow — Voice Dictation Research & Recommendations

Research and build recommendations for this app's voice pipeline: custom vocabulary, voice commands, the talk-vs-type register problem, and local ASR architecture.

**Home:** this belongs here — it was originally drafted in the wrong repo (a marketing-skills content marketplace, unrelated to this app) and has been moved to live alongside the code it's actually about.

## How this was researched

Four parallel research passes covered: (1) ASR architecture & latency engineering, (2) custom vocabulary & voice command design, (3) the talk-vs-type/register question, (4) builder lessons learned, evaluation methodology, and privacy architecture.

**Sourcing honesty note:** the session that produced this hit a network policy that blocked direct fetches to arbitrary external domains. That means three sources (a Medium post on cutting dictation lag from 20s to 2s, a Swift dictation-app build log, and Wispr Flow's "dictation for developers" post) were reconstructed from search-engine corroboration rather than read end-to-end, and two sources (a paywalled Substack post, one YouTube video) couldn't be reached or identified at all. Every claim below still carries its source so anything load-bearing can be checked before you build on it.

---

## TL;DR — direct answers

1. **Custom dictionary: build it.** Every serious product in this space has one (Wispr Flow, Superwhisper, Talon). Use a layered design, not a single mechanism — see Part 1.
2. **Voice commands/macros: build it, but design the mode-switch first.** The hard problem isn't execution, it's telling "this is a command" apart from "this is dictated prose that happens to contain those words." Every reference implementation solves this architecturally, not by statistically guessing — see Part 2.
3. **Talk vs. type: yes, and the target register should be "how you'd type this specific message," not "correct written English."** This is a real, named linguistic phenomenon, and the best products already treat the target register as *variable* by context, not fixed — see Part 3.
4. The single most useful engineering lesson across all the research: **instrument before optimizing.** The builder who cut lag from 20s→2s assumed Whisper was the bottleneck; it wasn't (0.74s) — an LLM "polish" pass was silently eating 19 of those seconds. See Part 4.

---

## Where this connects to the current codebase

This research was written generically, then landed in a repo that's already a working, shipping app (README: CI green, a signed build has reached TestFlight). A few direct tie-ins worth reading first:

- **`initial_prompt` priming — this just came up.** The most recent commit on `main` disables `initial_prompt` priming "pending investigation." That's the exact mechanism Part 1 flags as the weakest layer of vocabulary customization: Whisper's prompt mechanism expects a continuation of prior speech, not a keyword list, and research found it can measurably *raise* WER and induce hallucinated words when used as a bias list. Before re-enabling it, read Part 1's layer comparison — the deterministic find-and-replace layer (post-transcription substitution) is very likely the safer path for whatever vocabulary problem `initial_prompt` was being asked to solve, and it's also the layer MacWhisper ships as its *only* mechanism.
- **VAD.** The README's Known Limitations already flags energy-threshold VAD as a deliberate v1 simplification, noting `whisper_full_params.vad` exists in whisper.cpp but isn't wired up, specifically to avoid a second model download. Part 4's VAD section (Silero vs. Picovoice Cobra vs. others) is about *external* VAD models — all of which cost a download. Given that constraint already shapes this codebase, wiring up whisper.cpp's own native VAD flag is probably the more relevant near-term move than adopting an external VAD library, and isn't something the general research anticipated.
- **Language routing is genuinely uncharted relative to this research.** The two-pass Singlish-first-then-reclassify design (transcribe once, classify script/keywords, only re-transcribe if confident it'll help) solves a problem — routing across multiple monolingual models for code-switched speech — that none of the competitor research covers. Wispr Flow, Superwhisper, and Talon are all effectively single-language-model products. Nothing in Parts 1–9 should be assumed to transfer to the classifier/routing layer without separate validation.
- **No LLM cleanup pass exists yet.** Part 3's register-matching recommendation (ITN → disfluency removal → punctuation → a small local LLM for register/tone) is pure greenfield here. It would mean running a small on-device LLM (llama.cpp/MLX-class, 3B-ish per the latency lesson in Part 4) alongside whisper.cpp — worth prototyping the latency budget before committing to the UX.
- **Transcript history persistence.** The README notes history persists via SwiftData. Part 6's most actionable, least-obvious finding — local-only is not the same as private-at-rest, and most competitors ship plaintext local storage as an unexamined gap — is worth a direct check against this store specifically.
- **Voice commands are pure greenfield, but the keyboard extension already has a relevant precedent.** `NasarFlowKeyboard`'s existing handoff (tap Dictate → switch to the main app via `nasarflow://dictate` → transcribe → drop the result in a shared App Group / clipboard → switch back) is architecturally close to the hold-to-activate command-mode pattern Part 2 recommends starting with — the app-switch-and-return round trip is already solved for dictation; a command mode could plausibly reuse the same plumbing rather than needing new IPC.

---

## Part 1 — Custom dictionary: recommended architecture

Don't pick one mechanism — real products layer several, because each catches a different failure mode.

| Layer | What it does | Catches | Watch out for |
|---|---|---|---|
| **1. Deterministic find-and-replace** | Post-transcription exact/case-insensitive substitution against a user-maintained list | Systematic, known-wrong transcriptions ("Nassar" → "Nasar") | Cheapest, safest, zero model risk — **build this first** |
| **2. Fuzzy/edit-distance correction** | Levenshtein-based matching (e.g. FuzzyWuzzy/TheFuzz) against your dictionary, run on low-confidence or out-of-vocabulary-shaped tokens | Near-miss phonetic spellings you didn't anticipate | Needs a distance threshold tuned to avoid over-correcting real words |
| **3. Contextual biasing / hotword lists** | Engine-level: a wordlist that biases the decoder toward given spellings (NeMo/Parakeet-style shallow fusion or word-spotting) | Words the model would otherwise never produce, even after correction | Over-biasing measurably *degrades* accuracy on unrelated words past some list size — keep lists short and targeted |
| **4. Prompt-based biasing (Whisper `initial_prompt`)** | Prepending text to bias the decoder | Same as #3, Whisper-specific | Weakest option: Whisper's prompt mechanism expects a *continuation of prior speech*, not a keyword list — research found it can measurably **raise** WER and induce hallucinated words when used as a bias list. Use sparingly, if at all. |

*(Sources: NVIDIA NeMo word-boosting docs, "TurboBias" arXiv:2508.07014, Whisper prompt-limitation analysis arXiv:2410.18363 and arXiv:2502.11572, Metaphone/phonetic-matching background.)*

**How the competition does it:**
- **Wispr Flow**: a "Personal Dictionary" that auto-learns from corrections (up to 4-word phrases), plus manual entries, synced across devices, bulk CSV import, shareable as a team dictionary. Explicitly splits into (a) recognition-time *boosting* and (b) deterministic *misspelling replacement rules* — i.e., it already does layers 1 and 3 above as distinct features.
- **Superwhisper**: ships both a "Vocabulary" (recognition-time hints) and "Replacements" (deterministic post-processing) — but its own docs recommend using Vocabulary *sparingly* because it "can cause complications," and treat Replacements as the primary, reliable mechanism. This is a direct, first-party confirmation of the risk noted in layer 4 above.
- **MacWhisper**: reportedly has **no true vocabulary injection at all** — pure text-substitution (layer 1 only) — and still ships as a well-regarded product. That's a useful signal: layer 1 alone is a legitimate, shippable MVP.

**Recommendation:** ship layer 1 (deterministic replace) at launch — it's most of the value for least risk. Add layer 2 (fuzzy match) once you have real failure data from users. Only reach for layers 3/4 if you have a specific class of words (e.g. your own product/client names) that layer 1+2 keeps missing, and A/B test for regressions on unrelated speech before shipping.

---

## Part 2 — Voice commands & macros: recommended architecture

The mistake to avoid: trying to build a classifier that guesses, per-utterance, "is this a command or dictated text?" Every serious reference implementation sidesteps that problem entirely instead of solving it statistically:

| Product | How it avoids the ambiguity | Mode-switch mechanism |
|---|---|---|
| **Wispr Flow** | Dedicated **Command Mode**: hold a shortcut, speak the instruction, release, it executes | The held key *is* the mode switch — no ambiguity possible |
| **Talon Voice** | Two disjoint modes (command vs. dictation) rather than one grammar classifying each utterance; commands are additionally scoped per-application via "Context" definitions, so a command phrase isn't even in the active grammar unless its app is focused | Explicit mode commands, ~0.3s silence timeout before executing, an escape/"say literally" path to drop into text without leaving command mode |
| **Apple Voice Control** | Same disjoint pattern: Dictation mode (default) vs. explicit Command mode; separate sleep/wake pair fully suspends listening | Verbal mode switch ("Command mode") |
| **Windows Voice Access** | Three modes: Dictation-only, Commands-only, Default (both) — real users report the *mixed* Default mode is where confusion actually happens | Verbal mode switch |

**The pattern, stated plainly:** hold-to-activate (Wispr Flow's approach) is the simplest and lowest-risk to build — you get zero ambiguity for free, at the cost of an extra keypress. Always-on mode-switching (Talon/Apple/Windows) is more "hands-free" but needs the mode boundary itself to be unambiguous (verbal switch + timeout + escape hatch), and Talon adds a second safety net most people skip: **scoping commands to the focused app** so a command word isn't even recognized as a command unless that app is active.

**Execution mechanism** — two options, and it matters which you pick:
- **OS accessibility APIs** (macOS `NSAccessibility` / `accessibilityPerformPress()`, Windows UI Automation) — addresses a named/semantic control directly. Windows' own Voice Access docs call the UIA-numbered-control approach the *most reliable* click method, specifically because it doesn't depend on coordinates or focus state.
- **Simulated keystrokes** — the universal fallback for apps that expose no accessibility tree, and the *right* choice for pure text-editing actions where a keystroke is the native action anyway. Talon defaults to this and layers accessibility calls on top only where the OS supports it. Don't assume keystroke simulation is inherently unreliable, but prefer accessibility APIs when a target is a real, named UI control.

**Recommendation:** ship hold-to-activate command mode first (lowest engineering risk, matches Wispr Flow's proven pattern) — and note the keyboard extension's existing app-switch-and-return plumbing (see "Where this connects to the codebase" above) as a plausible starting point. If you later want always-on hands-free control, study Talon's context-scoping model closely before attempting your own ambiguity classifier — nobody in this space ships a classifier for this; they all ship a boundary.

---

## Part 3 — The talk-vs-type problem

Your instinct — "a voice message to a friend should come out exactly as if I'd typed it to that friend" — is linguistically well-founded, not just a vibe.

**Why the gap exists:** Douglas Biber's foundational corpus-linguistics work (*Variation Across Speech and Writing*, 1988) found that speech and writing aren't two clean bins — they sit on a continuum whose main axis contrasts "involved" (interactive, real-time, personal) production against "informational" (dense, planned, edited) production. Casual conversation and personal messages cluster together on the *involved* end; edited prose sits far away. That's precisely why a verbatim transcript of speech "reads as an error" once it's typed — it's not that speech is sloppy, it's that you're comparing the wrong two points on the continuum. David Crystal's analysis of informal typed messaging ("Netspeak") goes further and argues casual texting is its own third register blending speech and writing, not simply "cleaned-up speech" — which is exactly the target you described.

**What the pipeline needs to actually do**, in order:
1. **Inverse Text Normalization (ITN)** — spoken-form → written-form ("three pm" → "3pm", "dot com" → ".com"). Industry-standard implementation is rule-based (WFST grammars, e.g. NVIDIA's NeMo-text-processing/Pynini), specifically *because* the task has near-zero tolerance for silent, confident-looking errors — neural/seq2seq approaches are documented as more hallucination-prone here.
2. **Disfluency removal** — stripping "um," "uh," false starts, repeated words, self-corrections. Academic estimates put disfluencies in roughly a third of sentences even from strong modern ASR. Sequence-tagging models (mark spans as reparandum/interregnum/repair, then delete) are the traditional approach; recent work found that prompting a general LLM to do this tends to *paraphrase* rather than surgically delete the disfluent span — worth knowing if you reach for an LLM here.
3. **Punctuation restoration & capitalization** — the best low-latency designs use small dedicated classifiers (not a full LLM) riding a few words behind the decoder, some hitting ~3-4 word lookahead. This should not be where you spend your latency budget.
4. **The register-matching pass (LLM cleanup)** — this is where Wispr Flow and Superwhisper actually differentiate, and where the real risk lives.

**The over-correction trap (read this before you build step 4):** the research surfaced a consistent, specific complaint pattern about Wispr Flow's cleanup layer: reviewers report it sometimes "improves what they actually said instead of transcribing it accurately," flattening casual phrasing into formal language and, in the worst cases, changing meaning — cited as a factor in a middling 2.7/5 Trustpilot average. This isn't a one-off; it mirrors a broader finding in LLM-based ASR-correction research, that directly prompting an LLM to "fix" a transcript risks hallucinated edits to text that was already correct.

**How the better products manage this risk:**
- **Wispr Flow** exposes a tunable intensity dial — Light (fillers + grammar only, minimal restructuring) / Medium (default) / High (heaviest rewriting) — plus a "Backtrack" feature for handling spoken self-corrections explicitly rather than silently guessing.
- **Superwhisper** ships per-app "Custom Modes" — a different prompt, model, and auto-activation rule depending on the focused app (e.g. Slack mode stays casual, Email mode adds greeting/signature) — running fully offline via Ollama.

**Recommendation:**
- Default the register target to "informal typed message" (Biber's "involved" end), not "correct written English" — that's the right target for the friend-message use case you described.
- Make the register **contextual** (per destination app, like Superwhisper) rather than a single global cleanup level.
- Keep the raw transcript retrievable/undoable behind the cleaned version — given how consistently over-correction shows up as a complaint, users need an escape hatch when the cleanup layer guesses wrong about their intent.
- Do ITN and punctuation with small, fast, deterministic-leaning components; reserve the LLM specifically for register/disfluency, where deterministic rules can't do the job — don't let one heavy LLM pass do everything (see Part 4's latency lesson — this is exactly the stage that ate 19 seconds in one real build).

---

## Part 4 — Architecture blueprint for local real-time ASR

### The most important lesson in this entire research pass

The builder who cut dictation lag from 20 seconds to 2 (source: reconstructed via search) assumed Whisper itself — "computationally heavy" — was the bottleneck. He was wrong. He instrumented every pipeline stage with timestamps instead of guessing, and found Whisper ran in **0.74 seconds**. The real bottleneck was a separate local-LLM "polish" pass (via Ollama) cleaning up the raw transcript — silently consuming **~19 of the 20 seconds**. The fix wasn't a faster ASR model; it was swapping to a smaller local LLM (a 3B-class model matched a 9B model's cleanup quality at a fraction of the latency). Total: ~2 seconds.

**Take this literally here:** instrument every stage (capture → VAD → ASR → post-processing → LLM cleanup → text insertion) with timestamps from day one. Do not optimize the ASR model before you've measured where time is actually going — it's very likely not where you assume.

### Model choice, for context

This app already runs whisper.cpp via its own `whisper.xcframework`, so the model-choice question below is more "which whisper.cpp variant/quantization" than "which engine" — but it's worth knowing the wider landscape before assuming whisper.cpp is the ceiling:

| Engine | Streaming-native? | Approx. accuracy | Approx. speed (reported) |
|---|---|---|---|
| whisper.cpp (large-v3, GGUF Q5_1) | No — needs retrofitting | ~2.0–2.5% WER (LibriSpeech-clean) | 5–7x realtime via CoreML on M2 Pro |
| faster-whisper (CTranslate2) | No — needs retrofitting | Comparable to whisper.cpp | 8–12x realtime on RTX 30/40-series (not applicable on iOS) |
| distil-whisper | No | ~9.7% WER vs 8.4% for large-v3 (out-of-domain) | ~6x faster than large-v3 |
| NVIDIA Parakeet-TDT (0.6B) | Yes — native | ~2.6% WER (rivals large-v3) | ~30x realtime on a laptop CPU |
| Moonshine (useful-sensors) | Yes — native | Competitive on short utterances | 50–260ms latency depending on model size |
| Apple SpeechAnalyzer/SpeechTranscriber | Yes — native | Beats Whisper Small on long-form speech per one report | ~3x faster than Whisper Small per second of audio |

Since Whisper's whole family is fundamentally batch-oriented and needs retrofitting to feel real-time, this is worth revisiting specifically for the "auto-stop after silence" UX this app already has — whisper.cpp's own native VAD (see "Where this connects to the codebase" above) is the lowest-effort next step before considering a swap to a natively-streaming engine.

### VAD & endpointing

Silero VAD is the most widely used external option but isn't the most accurate one available — one benchmark found it misses ~12% of speech frames at a 5% false-positive rate; Picovoice Cobra reportedly does notably better (1.1% miss rate, faster). The bigger design decision is the endpointing threshold itself: too short (~200ms) cuts users off; too long (~800ms+) adds a felt latency tax. Dictation's longer utterances need more conservative thresholds than conversational turn-taking.

### Quantization & hardware acceleration

GGML/GGUF quantization is close to a free lunch at moderate levels — Q5_1 loses under 1% WER versus full precision. On Apple Silicon/iOS, converting to Core ML unlocks the Neural Engine specifically (not just Metal/CPU) — worth checking whether `whisper.xcframework`'s build already does this, since it's built via whisper.cpp's own `build-xcframework.sh`.

---

## Part 5 — Lessons learned from builders who shipped this

- **On-device is the differentiator, not raw accuracy.** Several recent "Show HN" launches (Whispering, Rekody, Ghost Pepper, Utter) all lead their pitch with local/offline processing rather than accuracy claims — that's this app's positioning lane already, and it's a crowded-but-validated one.
- **Domain-matched training data beats chasing generic benchmarks.** Aqua Voice (YC W24) trained its own model specifically on developer speech (code, terminal commands) rather than generic audiobook-style corpora, and reports 97% accuracy on jargon like "kubectl." Directly analogous to this app's own Singlish/Arabic fine-tunes — the same principle justifies continuing to invest in dialect-specific models over a single generic one.
- **Accuracy for non-native accents/dialects remains the industry's hardest unsolved problem.** Even Talon Voice's own community — arguably the most demanding, technical user base in this space — maintains a dedicated wiki just for tuning pronunciation and mic setup, rather than expecting out-of-box accuracy to suffice. Directly relevant given the Arabic model's own model card already reports ~43% WER on dialectal Arabic.
- **A privacy incident is survivable; a bad first response is not.** Wispr Flow's 2025 incident (a user's network monitor caught the app uploading window screenshots and audio to third-party cloud infra) blew up specifically because the company's first move was banning that user. Worth remembering given this app's whole positioning is "nothing is uploaded anywhere."
- **Churn is driven by social discomfort and correction fatigue, not raw accuracy.** Talking to a machine around other people rarely survives an open office, and it's reportedly "the tenth error, not the first" that breaks a user's habit of trusting the tool.
- **Hold-to-talk reportedly beats always-on listening** — always-on forces constant "microphone management" (pausing to avoid capturing side conversation), while hold-to-talk gives explicit control. This app's push-to-record model already matches the recommended pattern.
- **Even Wispr Flow, the category leader, admits a sequencing mistake**: their own strategy writing describes pushing toward "voice-to-action" and wearable ubiquity before nailing reliable input first, citing Humane's AI Pin as the cautionary example. Worth keeping in mind before reaching for voice commands (Part 2) ahead of hardening the core dictation loop.

---

## Part 6 — Privacy & local-first, done right

- **"Never leaves your device" needs to be independently verifiable, not just claimed.** The credible version of this claim is checkable by any user with a standard network monitor in under a minute. This app's README already states this plainly — worth keeping it that easy to verify as features are added.
- **Local-only is not the same as private-at-rest — the least obvious and most actionable finding here.** An audit of six dictation apps found three storing transcripts and audio locally as **unencrypted plaintext with no lock**. Only one of six encrypted at rest (AES-256-GCM). Worth checking directly against this app's SwiftData transcript history.
- **Model updates without phone-home:** the credible pattern is fixing model weights at build/install time and updating only through explicit, user-initiated app updates — this app's `ModelDownloadService` + GitHub Release assets + checksum verification already matches this pattern well.
- **The "on-device is too slow/hot" complaint usually isn't fundamental — it's a model/hardware mismatch.** Worth keeping in mind if larger models are ever offered as an option beyond the current Singlish/Arabic/English/multilingual set.

---

## Part 7 — How to evaluate quality, beyond WER

Word Error Rate treats every error as equally bad, which is misleading for a real product: "Boston" → "Austin" is one word wrong but a completely failed task; "morale is raised" → "morale is razed" is one word wrong but inverts the meaning. Both score identically to a trivial typo. For a dictation tool specifically, WER also says nothing about punctuation, formatting, or latency.

**Recommendation:** don't optimize for WER as the primary internal metric — especially relevant given the Arabic model's own card already reports both WER and CER on dialectal speech, which won't fully reflect real-world usability. Track edit-distance-after-correction from real usage, and keep a small hand-labeled set of Singlish/Malay/Arabic code-switching cases to sanity-check both the language classifier and the custom-dictionary work in Part 1.

---

## Part 8 — Recommended reading

- **Douglas Biber, *Variation Across Speech and Writing* (1988)** — the foundational linguistic account of why spoken and written register differ.
- **AssemblyAI, "Word error rate is broken"** — the clearest practitioner-level explanation of WER's blind spots and what to measure instead.
- **Wispr Flow, "The Master Plan"** — the category leader's own strategy writing, including their admitted sequencing mistake.
- **Talon Voice Community Wiki** (talon.wiki) — a living, community-maintained handbook of edge cases from the most demanding voice-control users that exist.
- **NVIDIA NeMo-text-processing / Pynini docs** — the reference implementation approach for production-grade ITN.
- **whisper-streaming ("LocalAgreement" paper, arXiv:2307.14743)** — relevant if this app ever needs true mid-utterance streaming rather than record-then-transcribe.

---

## Part 9 — Suggested build order

A phased path that front-loads the cheapest, lowest-risk wins and defers the hardest ambiguity problems until the core loop is proven — adjusted for what already exists in this codebase:

- **Phase 0 — already largely done.** VAD (energy-threshold), ASR (whisper.cpp), basic pipeline all exist. The one open item: resolve the `initial_prompt` question (see "Where this connects to the codebase") before it becomes a vocabulary-customization dead end.
- **Phase 1 — talk-vs-type quality (greenfield).** A small local LLM cleanup pass (start at 3B-class, not 8–9B) with a light/medium/high dial, defaulting to "informal typed message." Keep the raw transcript one tap away.
- **Phase 2 — custom dictionary (greenfield).** Ship deterministic find-and-replace first — and note it's a strict improvement over the currently-disabled `initial_prompt` approach, not just an alternative to it. Add fuzzy matching once you have real user-reported misses.
- **Phase 3 — voice commands (greenfield).** Hold-to-activate command mode, reusing the keyboard extension's existing app-switch/App-Group plumbing where possible.
- **Phase 4 — privacy hardening.** Verify the SwiftData transcript store's at-rest encryption status specifically.
- **Phase 5 — real evaluation.** Edit-distance-after-correction and a hand-labeled Singlish/Malay/Arabic code-switching set, not raw WER, as the ongoing quality bar.
