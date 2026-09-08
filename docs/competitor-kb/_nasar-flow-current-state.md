# Nasar Flow — current state (baseline for competitor gap analysis)

> Snapshot taken 2026-09-08 from three repos: iOS `MultilingualWhisper` (main @ `6bb391a`), Android `NasarFlowAndroid` (master @ `c5c293f`), and the marketing site `nasarflow-site` (not a git repo; live at https://flow.nasar.sg). Everything below is read from code/docs, not from running the app. "iOS" paths are relative to `C:\Users\aarif\Claude MCP\MultilingualWhisper\`, "Android" paths to `C:\Users\aarif\Claude MCP\NasarFlowAndroid\`, "site" paths to `C:\Users\aarif\Claude MCP\nasarflow-site\`.

## Platforms & distribution status

| Platform | Status | Evidence |
|---|---|---|
| **iOS app** (`com.multilingualwhisper.app`, product name "Nasar Flow", iOS 17.0+) | Private TestFlight beta, invite-only via website. Signed releases built entirely on GitHub Actions macOS runners (no Mac anywhere in the loop). Last TestFlight upload (2026-09-08, run 34221081212) carries Flow sessions + CPU-only decode fix. **Four CI-green features on `main` are NOT yet on TestFlight**: per-segment code-switching reroute (`8425bd4`), Custom Dictionary (`6bb391a`, PR #1), `FlowSessionEngineTests`, XCUITest layer. | `README.md` "Status"; `.github/workflows/release.yml`; `project.yml` (`MARKETING_VERSION: "1.0.0"`, `CURRENT_PROJECT_VERSION` bumped per run); `Utils/Constants.swift` `appVersion = "1.0.0"` |
| **iOS keyboard extension** (`com.multilingualwhisper.app.keyboard`, "Nasar Flow" keyboard) | Shipped inside the same TestFlight build since 2026-09-07. Requires "Allow Full Access" (`RequestsOpenAccess: true`). | `NasarFlowKeyboard/`, `project.yml` line 136 |
| **Android** (`sg.nasar.flow`, minSdk 26, targetSdk 36) | Pre-release prototype. Unsigned debug APK produced as a CI artifact on every push (`nasar-flow-debug-apk`); no Play Store, no signed build, no distribution page. Emulator-verified (record → transcribe → insert works; native build was unoptimized until `dba8210`); **never run on a real device**. Singlish model only. | `README.md` "What's real vs. what's a stub"; `.github/workflows/ci.yml` "Upload debug APK" |
| **macOS / Windows** | Not started. Listed on the site roadmap as "After iPhone". | site `public/roadmap.html` |
| **Pricing** | "Free during the beta." No IAP, no account, no paywall code anywhere. | site `public/faq.html`; no StoreKit references in iOS sources |
| **Source** | MIT, public on GitHub (`aarif86/MultilingualWhisper`). Android repo is a separate repo. | `README.md` "License"; `Utils/Constants.swift` model URLs |

## Activation & capture UX

### iOS app (Transcribe tab)
- **Toggle record**: one big `RecordButton` (88pt circle, mic → stop icon). Tap to start, tap again to stop. No push-to-talk/hold, no hotkey, no widget, no Shortcuts/Siri intent, no Watch, no Lock Screen/Control Center control. `Views/Components/RecordButton.swift`, `Views/TranscriptionView.swift`.
- **Feedback while recording**: button scales with mic level (`scaleEffect(1 + level*0.12)`), "Listening…" banner, `mm:ss` elapsed counter, and a **live preview transcript** re-decoded every 2s from the growing buffer using the pinned model (or Singlish when Auto). `ViewModels/TranscriptionViewModel.swift` `startLiveUpdates()`/`performLiveUpdate()`. No waveform, no sounds/haptics.
- **Auto-stop on silence (VAD)**: energy-threshold RMS VAD, `silenceTimeout` 2.5s, 1.2s grace period after start, threshold = `vadSensitivity * 0.015`. User-toggleable (`autoStopOnSilence`) with a 0…1 sensitivity slider. `Services/AudioService.swift` `evaluateVAD`.
- **Audio session**: `.record` / `.default` mode / `.duckOthers`; AVAudioEngine tap → AVAudioConverter → 16kHz mono Float32. `Services/AudioService.swift`.
- **After stop**: "Transcribing…" banner, then final text replaces preview (never replaced by an empty result), language badge shows components ("Arabic + Malay + Singlish"), word count + duration. Copy / Share (ShareLink) / Clear buttons. Result auto-saved to History. `Views/TranscriptionView.swift`.
- **Mode switcher on the main screen**: a globe button cycles `LanguageMode` (Auto / Force Singlish / Force Malay / Force Arabic / Force English / Multilingual). `TranscriptionViewModel.cycleLanguageMode()`.
- **Permission handling**: distinguishes "never asked" from "denied"; on denied shows an alert with an "Open Settings" deep link. `TranscriptionViewModel.startRecording`, `AudioService.isPermissionDenied`.

### iOS keyboard — two paths (`NasarFlowKeyboard/KeyboardViewController.swift`, `KeyboardView.swift`)
Hard constraint: iOS blocks mic access from keyboard extensions entirely, so the keyboard never records. It is a **dictation-only keyboard**: no letter keys at all, only a globe (next-keyboard) button plus the dictation controls. Height 240pt.

1. **Quick Dictate (legacy one-shot)**: keyboard opens `nasarflow://dictate` → app shows full-screen `QuickDictateView`, auto-starts recording, on finish publishes text to the App Group + clipboard and shows "Saved and ready to insert… switch back". User switches back manually; keyboard shows a **"Tap to insert"** row. `Views/QuickDictateView.swift`, `ViewModels/QuickDictateViewModel.swift`, `Shared/DictationHandoff.swift`. (The keyboard UI currently only exposes "Start Flow", not "Dictate", so this path is reachable via URL but not from the shipped keyboard UI — see `KeyboardView.startFlowButton`.)
2. **Flow session (current, modelled on Wispr Flow)**: keyboard shows **"Start Flow"** → opens `nasarflow://startflow` → `FlowActivationView` ("Flow is on", animated swipe-back gesture illustration) → `FlowSessionEngine.activate()` starts a *continuously running* `AVAudioEngine` with `UIBackgroundModes: audio` so the app stays alive in the background. User swipes back to the host app. Keyboard now shows **"Tap to speak"** → posts Darwin notification `startUtterance` → app buffers audio → **"Listening… Ns – tap to stop"** → `stopUtterance` → app transcribes (CPU-only decode, since GPU is forbidden in background) → publishes to App Group + clipboard → keyboard shows "Tap to insert" row. Keyboard reconciles state on a 1s tick, 2.5s start-confirm timeout, 20s result timeout, explicit "Couldn't transcribe that – tap to try again" state via `FlowSessionState.lastFailureAt`. `Services/FlowSessionEngine.swift`, `Shared/FlowSessionState.swift`, `Shared/DarwinNotification.swift`, `Views/FlowActivationView.swift`.
   - Flow can also be toggled in-app: Settings → "Flow" toggle. While on, the mic stays open the whole time (footer warns about battery). `Views/SettingsView.swift`.
   - `AudioService` refuses to start a normal recording while a Flow session is active ("Turn off Flow in Settings first"). `AudioService.startRecording`.
   - Activation confirmed on a real device (background engine survives ≥26s, Darwin signals arrive); end-to-end insert after the GPU fix is **still unconfirmed by the user**.
- **No VAD/auto-stop in Flow sessions** — utterances are purely tap-start/tap-stop (`FlowSessionEngine` has no silence logic). No live preview in the keyboard.

### Android IME (`app/src/main/java/sg/nasar/flow/keyboard/`)
- Records **in-process** inside `InputMethodService` (no Apple-style restriction). Keyboard surface: one full-width mic button ("🎤 Tap to speak" → "● Listening… Ns – tap to stop" → "Transcribing…" spinner), one QWERTY top row (q–p only), and a bottom row (🌐 picker, ⌫, space, ⏎). `KeyboardScreen.kt`.
- First mic tap without `RECORD_AUDIO` hands off to `MicPermissionActivity` (system dialog, then app-settings fallback on hard denial). Mic tap before the model is downloaded shows a Toast and opens `MainActivity` to download. `NasarFlowInputMethodService.onMicTapToStart`.
- Toggle tap-to-start/tap-to-stop only. No VAD, no auto-stop, no live preview, no level meter. In-flight recording/decode is cancelled if the keyboard is dismissed (`resetMicState`).
- **Main app** (`MainActivity.kt`) is a single "transcription test screen": Download model (progress + checksum verify) → "Tap to record" → "Tap to stop and transcribe" → transcript text. No tabs, no history, no settings.

## Text insertion mechanism (per platform)

| Platform | Mechanism | Details |
|---|---|---|
| iOS app | Manual | Copy button (`UIPasteboard`), Share sheet (`ShareLink`), selectable text. Nothing is auto-inserted anywhere. |
| iOS keyboard | `textDocumentProxy.insertText(text)` on user tap of the "Tap to insert" row | Result arrives via App Group `UserDefaults` (`DictationHandoff.publish/pending/clearPending`) **and** is copied to the system clipboard as a universal fallback. Inserted at the cursor as-is — no leading/trailing space logic, no capitalisation-by-context, no selection replacement. **Undo**: after insert, a "Not what you said? Tap to remove" row calls `deleteBackward()` once per character of the last insert. Keyboard deliberately stays active after insert (no `advanceToNextInputMode`). `KeyboardViewController.insert/undoLastInsert`. |
| Android IME | `currentInputConnection.commitText(text, 1)` immediately when the decode finishes | Automatic, no confirm step, no undo. Blank results insert nothing. Letter keys `commitText` single chars; backspace = `deleteSurroundingText(1,0)` or deletes selection; Enter performs the field's declared IME action else sends `KEYCODE_ENTER`. `NasarFlowInputMethodService.stopListeningAndTranscribe/onBackspace/onEnter`. |

Neither platform: accessibility-API insertion, typing simulation, per-app formatting, cursor-context awareness, or a desktop overlay.

## Models & language routing

**Engine**: whisper.cpp, greedy sampling, `no_context = true`, `translate = false`, threads = cores−1 (iOS) / 2–4 (Android). iOS: prebuilt `whisper.xcframework`, **CPU-only** (`use_gpu = false`, required for background decode). Android: whisper.cpp built from submodule via NDK/CMake, now forced `-DCMAKE_BUILD_TYPE=Release`. `Services/WhisperEngine.swift`; Android `whisper/src/main/cpp/jni.c`.

**Models (iOS, all Whisper-small class)** — `Utils/Constants.swift`, `Models/LanguageTypes.swift`:

| Model | Source | Size | Hint | Checksum |
|---|---|---|---|---|
| Singlish (default) | `jensenlwt/whisper-small-singlish-122k`, q5_1, GitHub Release | ~190 MB | `en` | yes |
| Malay | `mesolitica/malaysian-whisper-small-v2`, q5_1 | ~190 MB | `ms` | yes |
| Arabic ("beta") | `oddadmix/whisper-small-arabic-dialectal` (colloquial, ~43% WER per its card), q5_1 | ~190 MB | `ar` | yes |
| English | stock `ggml-small.en.bin` from `ggerganov/whisper.cpp` | ~488 MB | `en` | no |
| Multilingual | stock `ggml-small.bin` | ~488 MB | auto | no |

All downloaded on demand from Settings (pause/resume via URLSession resume data, SHA-256 verified, stored in Application Support, excluded from iCloud backup). `Services/ModelDownloadService.swift`. Android: only `ggml-small-singlish.bin` (same URL/checksum), no pause/resume. `app/.../model/ModelManager.kt`.

**Routing (iOS)** — `Services/WhisperService.swift`, `Services/LanguageClassifier.swift`:
- `LanguageMode` pinned modes call `transcribe(samples:using:)` with the pinned model.
- **Auto-Detect** = `transcribeWithAutoRouting`:
  1. Draft pass with Singlish model (hint `en`), split into ~30s chunks, segments kept with timings.
  2. `RuleBasedLanguageClassifier.classify(text:)` — Arabic Unicode-block ratio + keyword sets (`arabicKeywords`, `romanizedArabicMarkers`, `malayKeywords`, `singlishMarkers` in `Constants.swift`). Returns `recommendedModel`, `languageTag`, coarse `confidence`, and `components` list.
  3. **Whole-clip reroute** if recommended model ≠ Singlish, confidence ≥ 0.6, and that model is downloaded (Arabic if >40% Arabic script; Malay if Malay keywords with no Singlish particles).
  4. Otherwise **per-segment reroute** (`reprocessSegments`, merged `8425bd4`): for each draft segment ≥1.0s, re-run the default engine with `languageHint: nil` purely to read `whisper_full_lang_id`; if it says `ar`/`ms` and that model is downloaded, re-decode that slice with the Malay/Arabic model and splice the text back in. Costs one extra decode per probed segment.
  - Only Arabic and Malay ever trigger reroutes; English/Multilingual models are never auto-selected.
- Live preview always uses the pinned model or Singlish (never auto-routes).
- Classifier is swappable via the `LanguageClassifying` protocol; `docs/code-switching-research.md` documents why the text-cascade design is weaker than joint models and lists candidate replacements.

**Routing (Android)**: `LanguageRouter.kt` is a line-by-line port of the classifier with the same keyword lists (`RoutingKeywords.kt`) and unit tests, but it is **not wired to anything** — `TranscriptionEngine` loads only Singlish and passes `language = "auto"` in `jni.c` (not the `en` hint iOS uses).

## Accuracy / personalization features

| Feature | iOS | Android |
|---|---|---|
| **Custom Dictionary** | Yes (merged `6bb391a`, unshipped). Settings → Custom Dictionary → add "What Whisper hears" → "What it should say". Whole-word, case-insensitive regex substitution applied after every decode on every model (`WhisperService.joined`). Stored as JSON in `UserDefaults` (`customDictionary.entries`). No import/export, no auto-learning from corrections, no phrase-length limit, no per-language scoping, no fuzzy matching. `Services/CustomDictionaryService.swift`, `Models/DictionaryEntry.swift`, `Views/CustomDictionaryView.swift`. | No |
| **`initial_prompt` decoder biasing** | Code exists (`Constants.singlishInitialPrompt` / `arabicInitialPrompt`, plumbed through `TranscriptionOptions.initialPrompt`) but **disabled — `WhisperModelType.initialPrompt` always returns nil** since `c0a5c43`, after a real-device "nothing shows up" report. Research doc recommends leaving it off in favour of deterministic replacement. `Models/LanguageTypes.swift`. | No (jni.c sets no prompt) |
| **Per-segment reroute** | Yes (see routing). | No |
| **Language hint per model** | Yes (`en`/`ms`/`ar`/nil). | No (`"auto"`) |
| **Annotation-tag sanitizer** | Yes — strips IMDA corpus tags like `<SPK/>`, `<NON/>` that the Singlish fine-tune emits as text, collapses whitespace. `Utils/TranscriptSanitizer.swift`. | **Not ported** — Android will show raw `<SPK/>` tags. |
| Learning from user edits / contacts names / per-app context / screen context / spelling mode / snippets | None on either platform. | |

## Formatting / cleanup

- **Punctuation**: whatever Whisper emits. There is an **"Auto-punctuation" toggle** (default on); turning it *off* strips every non-alphanumeric, non-whitespace scalar from the final and live text (`TranscriptionViewModel.applyPunctuationPreference`). It cannot *add* punctuation. Not applied in Flow sessions (`FlowSessionEngine.transcribeAndPublish` publishes `result.text` directly) or on Android.
- **Filler/disfluency removal**: none. ("um", "uh", repeats pass through.)
- **Capitalisation / ITN** (numbers, dates, "dot com"): none beyond what the model emits.
- **Paragraphing / lists / tone modes / per-app styles / LLM cleanup / raw-vs-polished toggle**: none. `docs/voice-dictation-research.md` (unmerged branch) explicitly calls the LLM register-matching pass "pure greenfield".
- Segment texts are joined with single spaces; ~30s chunk boundaries are joined with a space (possible mid-word split at chunk edges — not handled). `WhisperService.runChunkedUninstrumented`.
- Android: `buildString { append(segment) }.trim()` — segments concatenated with **no separator**.

## Voice commands

None on any platform. No command mode, no "new line"/"delete that"/"undo", no mode switching, no macros. The only editing affordance is the keyboard's one-tap undo of the last insert (iOS) and the physical ⌫ key (Android). Voice commands are listed as Phase 3 greenfield in `docs/voice-dictation-research.md` (branch `docs/voice-dictation-research`).

## Privacy / storage

- **No network except model downloads** (GitHub Releases / Hugging Face). No analytics SDK, no account, no crash reporter, no telemetry. `README.md`; site `public/privacy.html`; Android manifest comment on `INTERNET`.
- **Transcript history (iOS)**: SwiftData store (`Transcription`: text, date, duration, languageUsed, modelUsed, isFavorite, notes) with `FileProtectionType.complete` applied to the SQLite main/-wal/-shm files on every launch. `Models/Transcription.swift`, `Services/PersistenceService.swift`. (`isFavorite`/`notes` fields exist but have no UI.) Falls back to in-memory if the store can't open.
- **Audio retention**: recordings are never persisted by default. Opt-in **"Save Recordings"** (`saveDebugAudio`, default off) keeps the last 5 utterances as 16-bit WAV in the App Group container (`DebugAudio/`), shareable/clearable from Settings. Only the in-app Transcribe path saves them; Flow-session utterances are not saved. `Shared/DebugAudioStore.swift`.
- **Debug log**: on-device text log in the App Group container (`debug.log`, trimmed at 1 MB), written by both app and keyboard, "Share Debug Log" / "Clear" in Settings. Never sent automatically. `Shared/DebugLogger.swift`.
- **Cross-process hand-off** puts the latest dictation text in App Group `UserDefaults` and on the **system clipboard** (`UIPasteboard.general`) — clipboard is readable by any app the user pastes into; pending text stays in the App Group until inserted.
- **Keyboard Full Access** is mandatory (needed to open the app via URL). Standard iOS Full Access privacy implications apply.
- **Models** stored in Application Support, excluded from backup; deletable per model from Settings ("Storage Used" shown).
- **Android**: model in `filesDir` (app-private); no transcript persistence at all; `allowBackup="true"` (default) in manifest.
- **Website** collects email only (sent to App Store Connect API for TestFlight invite) plus a self-hosted pageview log; no cookies. `public/privacy.html`, `server.js`, `lib/betaSignup.js`.

## Settings surface

### iOS — `Views/SettingsView.swift` (single Form, backed by `Models/AppSettings.swift` in `UserDefaults`)
1. **Language Settings** → Picker "Language Mode": Auto-Detect (Recommended) / Force Singlish / Force Malay / Force Arabic / Force English / Multilingual. (default Auto)
2. **Set Up Keyboard** button → `KeyboardSetupView` (4-step instructions + "Open Settings" link to the app's own Settings page; iOS has no deep link to the Keyboards list).
3. **Flow** section → Toggle "Flow" (starts/ends background session), "Listening…" indicator, last error text.
4. **Model Management** → one `ModelStatusRow` per model: Download / Pause / Resume / Verifying / Downloaded + Delete, progress %, approx size.
5. **Recording Settings**
   - Toggle "Auto-stop when silent" (default on)
   - Slider "Auto-stop sensitivity" 0…1 (default 0.7; disabled when auto-stop off)
   - Toggle "Auto-punctuation" (default on; off = strip punctuation)
   - Stepper "Chunk length: Ns" 10–60 step 5 (default 30) — **persisted but never read by any decode path** (`maxRecordDurationSeconds` is only referenced in Settings; `Constants.chunkDurationSeconds` is what `runChunked` actually uses). Dead setting.
6. **Custom Dictionary** → NavigationLink to list/add/delete corrections.
7. **Data Management** → "Storage Used", "Export All Transcriptions" (plain-text ShareLink: `[date] (language)\ntext`), "Clear All Transcriptions" (confirm dialog).
8. **Debug Log** → "Share Debug Log", "Clear Debug Log".
9. **Debug Recordings** → Toggle "Save Recordings" (default off), "Share Latest Recording", "Clear Saved Recordings".
10. **About** → Version 1.0.0, "Built for Singapore's multilingual community."

Not present: theme, haptics/sounds, hotkeys, per-app settings, language of UI (English only, no localisation files), font size, history retention limit, model auto-selection defaults, threads/performance, streaming toggle.

### iOS History tab — `Views/HistoryView.swift`
Search (case-insensitive substring), filter by `LanguageType`, Today/Yesterday/date grouping, swipe-to-delete, context menu Copy/Share/Delete, Export All, Delete All. Language badge recomputed live from the classifier. No favourites UI, no notes UI, no edit-in-place, no per-item re-transcribe.

### Android
No settings screen. `method.xml` `settingsActivity` points at `MainActivity` (the test screen). Single hard-coded `en_US` IME subtype.

## Onboarding

- **iOS**: no first-run flow, no tutorial, no permission pre-prompt. The app opens on the Transcribe tab; the mic permission system dialog fires on first Record tap. Models must be downloaded manually from Settings first — tapping Record with no model yields an error alert ("Singlish Model isn't downloaded yet."). Keyboard onboarding is the manual `KeyboardSetupView` checklist; Flow onboarding is the `FlowActivationView` "Flow is on" screen with the swipe-gesture illustration. Keyboard shows an "Enable Full Access" instruction card when Full Access is off.
- **Android**: no onboarding; MainActivity is a Download → Record test screen; IME must be enabled manually in system settings (README documents the path). Mic permission requested lazily via `MicPermissionActivity`.
- **Website**: email → automatic TestFlight external-group invite via App Store Connect API (`lib/appStoreConnect.js`, `lib/betaSignup.js`, group "Website Signups"). FAQ covers install expectations (TestFlight app, ~450 MB per model — stale, see below).

## Known limitations (README + code comments)

From `README.md` "Known limitations":
- Rule-based language classifier, not a trained model.
- Energy-threshold VAD, not learned; whisper.cpp's native VAD (`whisper_full_params.vad`) not wired up.
- Model downloads don't survive force-quit mid-download (no background `URLSessionConfiguration`).
- `PrivacyInfo.xcprivacy` reason code `CA92.1` needs re-checking before App Store submission.
- `exportOptions.plist` method value tied to Xcode 26.6.

From code comments / commit history:
- `initial_prompt` disabled pending investigation (`Models/LanguageTypes.swift`).
- Per-segment reroute reuses a full decode as a language probe instead of `whisper_lang_auto_detect` — "accepted for now, worth revisiting if this needs to get faster" (`WhisperService.rerouteIfNeeded`).
- Segments shorter than 1.0s are never probed (`minSegmentDurationToProbe`).
- Auto-routing only reroutes to Arabic/Malay; English/Multilingual never auto-selected.
- Flow session keeps the mic engine running continuously → battery cost; no auto-timeout of a session (`FlowSessionState.clear` mentions "or the app decides to time it out" but nothing implements it).
- Flow sessions: keyboard→app Darwin delivery confirmed, app→keyboard direction "unconfirmed either way", mitigated by 1s polling (`KeyboardViewController.reconcilePhase`).
- No supported way for the app to return the user to the host app automatically after activation; the earlier "‹ Back to App" claim was retracted (`Views/QuickDictateView.swift`, `FlowActivationView.swift`).
- Arabic model ~43% WER on its own held-out set (`README.md` "Model files").
- "Chunk length" setting is dead (see Settings).
- Chunk boundaries at fixed 30s sample counts, not on silence — can split words.
- Live preview re-decodes the entire buffer every 2s (cost grows with utterance length).
- No TODO/FIXME markers exist in either codebase (grep clean); limitations are expressed in doc comments.
- **Android** (`README.md` "What's real vs. what's a stub"): single model, no auto-routing, no resumable downloads, no download-management UI, no real keyboard layout, silent failure on transcription error, never run on a real device, no sanitizer/dictionary/punctuation parity with iOS.

## Unmerged branches and what they add

iOS (`git branch -a`), all on `origin/`:

| Branch | Adds | Status |
|---|---|---|
| `feature/native-language-id-precheck` (`ff89a4e`, merged-with-main twice, last base `6bb391a`) | `WhisperEngine.arabicLanguageProbability(samples:)` using `whisper_pcm_to_mel` + `whisper_lang_auto_detect`; `WhisperService.resolveDefaultModel` runs it on the first 3s of audio and starts auto-routing on the Arabic model when P(ar) ≥ `Constants.arabicPreCheckThreshold = 0.5`, skipping the wasted Singlish draft pass. Adds `arabicLanguageProbability` to `WhisperTranscribing` + tests. | CI-compiles; **"NOT YET VERIFIED ON A REAL DEVICE"** per its own doc comment. Threshold untuned. Up to date with main. |
| `docs/voice-dictation-research` (`bd7730a`) | `docs/voice-dictation-research.md` — 188-line research doc: layered custom-dictionary design, voice-command mode-switch patterns (Wispr Flow / Talon / Apple / Windows), talk-vs-type register pipeline (ITN → disfluency → punctuation → LLM), latency lessons, privacy-at-rest, evaluation beyond WER, suggested build order. **`README.md` and `CustomDictionaryService.swift` on main already cite this file, but it does not exist on main.** | Docs only; based on `c0a5c43`, never merged. |
| `debug/isolate-new-files-only`, `debug/isolate-whisperservice-change`, `debug/isolate-persistence-change`, `debug/isolate-persistence-runtime` | Temporary CI-bisection branches from the Custom Dictionary work (subsets of files, or `PersistenceService.swift` reverted). | Superseded by PR #1 (`6bb391a`); safe to delete. |

Android: only `master`; the one fix branch (`fix/native-release-optimization`) is already merged (`c5c293f`).

## What the website promises that the app doesn't yet do

Site copy read from `public/index.html`, `faq.html`, `roadmap.html`, `privacy.html`, `credits.html`.

| Site claim | Reality |
|---|---|
| "Four models, one app" / "Nasar Flow auto-detects which language you're in and routes to the right model" | Five models in the picker (English *and* Multilingual are separate rows). Auto-routing only ever picks Singlish/Malay/Arabic; the two fallback models are manual-only. Detection is keyword/script heuristics on a draft transcript, not audio LID (the site's roadmap does disclose "rule-based keyword matching"). |
| "switching between Singlish, Malay, Arabic and English mid-sentence, no need to pick one" | Mid-sentence switching is handled by the Singlish model's own tolerance plus the per-segment reroute (≥1s segments only, and **not yet on TestFlight**). The TestFlight build users have today does whole-clip reroute only. |
| FAQ: models are "roughly 450MB each" | The three custom models are ~190 MB after q5_1 quantisation; only the two stock models are ~488 MB. Stale copy. |
| FAQ/index: "Read, copy, export" — "search back through, or export whenever you need it" | True for the in-app Transcribe/History tabs. |
| Hero: "An iPhone app" — the whole site describes the in-app transcriber. **The keyboard extension and Flow sessions (dictate into any app) are not mentioned anywhere on the site**, despite being the feature the last two days of engineering went into and the closest thing to the Wispr Flow use case the founder note describes ("dictating a text to my wife"). | Under-promised: the site sells a transcription notepad, the app is trying to be a system-wide dictation keyboard. |
| Founder note compares directly to Wispr Flow and Willow ("neither could hold Arabic, Malay, and Singlish together") | Those products' core features (AI cleanup, filler removal, personal dictionary auto-learning, command mode, desktop apps) are absent; only the multilingual angle is delivered. |
| Roadmap "Shipped": "Dedicated Malay model", "Auto language routing" | Both shipped on TestFlight. Correct. |
| Roadmap "In progress": "Smarter language detection — a trained classifier is next" | No classifier training work exists in any repo; the only in-flight detection work is the unmerged native Arabic pre-check branch (whisper.cpp's own LID, not a trained Singlish/Malay classifier). |
| Roadmap "Planned": "Learned voice detection", "Resumable downloads", "Public App Store release" | None started. Pause/resume of downloads within a running app already works; only force-quit survival is missing. |
| Roadmap "After iPhone": Android "could end up simpler than the iPhone app itself" | Android prototype exists (not mentioned as existing on the site); it is simpler in architecture but currently far less capable (one model, no routing, no history, no settings, no sanitizer). |
| Privacy page: "The only network activity the app itself makes is downloading a speech model file" | Accurate. |
| Privacy page: "Your voice, your transcripts, and your history never leave your iPhone" | Accurate for the app; note the keyboard hand-off also places each dictation on the **system clipboard**, which the page doesn't mention. |
| Credits page lists whisper.cpp, Whisper, the three fine-tunes, XcodeGen | Accurate; does not credit the stock `ggml-small(.en)` models separately (they are whisper.cpp's own). |
| "No account required / No audio ever uploaded / Works fully offline / Open source on GitHub" | All accurate. |

### Things the app does that the site never mentions
Keyboard extension, Flow sessions, undo-last-insert, live preview while recording, language-component badge ("Arabic + Malay + Singlish"), Custom Dictionary (unshipped), Force-language modes, auto-stop VAD + sensitivity, export-all, debug log/recording sharing, per-model delete/storage view, Android prototype.
