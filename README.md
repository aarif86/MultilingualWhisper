# Multilingual Whisper

An offline, on-device speech-to-text iOS app tuned for Singlish, Malay, and Arabic —
including everyday code-switching between them ("Bismillah, let's go makan lah").
Transcription runs entirely on-device via [whisper.cpp](https://github.com/ggml-org/whisper.cpp);
nothing is uploaded anywhere.

Built and maintained without a local Mac: all compiling, testing, and TestFlight
distribution happens on GitHub Actions' macOS runners.

## Status

The full pipeline is proven end-to-end on this exact codebase, with no Mac
anywhere in the loop: [CI](.github/workflows/ci.yml) builds and tests pass, and
[a signed release](.github/workflows/release.yml) has successfully reached
TestFlight, carrying real converted Singlish and Arabic models (see
[Model files](#2-model-files)). See [Known limitations](#known-limitations)
below for what's still deliberately simplified.

## How it works

- **Recording** - `AVAudioEngine` captures the mic, resampled to 16kHz mono
  Float32 (what whisper.cpp expects), with a simple energy-threshold VAD that can
  auto-stop a recording after sustained silence.
- **Transcription** - [whisper.cpp](https://github.com/ggml-org/whisper.cpp) runs
  on-device via its own `whisper.xcframework` (built by whisper.cpp's own
  `build-xcframework.sh`), called directly from Swift through the framework's
  bundled module map - no Objective-C++ bridge needed.
- **Language routing** - there are up to four GGML models a user can download
  (Singlish, Arabic, English, general multilingual). "Auto-Detect" mode transcribes
  once with the Singlish model (it's the broadest net for Singlish/Malay/English
  code-switching), classifies the resulting text with a rule-based classifier
  (Arabic Unicode-block + keyword matching - see `LanguageClassifier.swift`), and
  only re-transcribes with a different model if the classifier is confident enough
  that it would do meaningfully better. This two-pass design exists because
  keyword/script matching needs *text*, which you don't have until something has
  already transcribed the audio once.
- **History & Settings** - transcriptions persist via SwiftData; app preferences via
  `UserDefaults`.

## Keyboard extension

`NasarFlowKeyboard` is a system-wide custom keyboard (a separate Xcode
extension target, `com.multilingualwhisper.app.keyboard`) with a "Dictate"
button, so Nasar Flow can be used for input in any app - Messages, Notes,
anywhere there's a text field - not just its own screens.

**It can't record audio itself.** iOS has blocked microphone access from
keyboard extensions entirely since iOS 8, and that's true even with "Full
Access" granted - there's no exception, by design (otherwise any installed
keyboard could silently record everything said, not just everything typed).
This isn't a shortcut specific to this app; it's the same wall every
third-party dictation keyboard hits, including well-known ones like Willow and
Wispr Flow. So the flow is:

1. Tap **Dictate** in the keyboard
2. It switches you to Nasar Flow (`nasarflow://dictate`), which records and
   transcribes using the exact same pipeline as the main app
3. The result is copied to your clipboard and dropped into a shared App Group
   container
4. Switch back to whatever you were doing - the keyboard shows an **Insert**
   button with a preview of the text, or just paste normally

### Extra setup this needs

Every extension has its own bundle ID, so this needs a second round of the
same Apple Developer Portal steps as the main app, plus an App Group so the
two processes can hand data to each other:

1. **Register a new App ID**: `com.multilingualwhisper.app.keyboard`
   (Certificates, Identifiers & Profiles → Identifiers → **+**)
2. **Enable "App Groups"** as a capability on *both* App IDs - the existing
   `com.multilingualwhisper.app` and the new `.keyboard` one
3. **Create the App Group** itself (Identifiers → App Groups → **+**):
   `group.com.multilingualwhisper.app`, then attach it to both App IDs
4. **Re-generate the main app's existing "Nasar Flow" profile** - it was
   created before App Groups existed on its App ID, so it's stale until you
   download a fresh copy (same name is fine, Apple lets you regenerate in place)
5. **Create a new profile for the keyboard**: Profiles → **+** → App Store
   distribution → the new `.keyboard` App ID → the same Apple Distribution
   certificate already in use → name it exactly **`Nasar Flow Keyboard`**
   (this exact string is hardcoded in both `project.yml` and
   `exportOptions.plist`)
6. Update the two GitHub secrets described in [Apple signing](#3-apple-signing-for-testflight-only)

After installing the TestFlight build with the keyboard included: **Settings
app → General → Keyboard → Keyboards → Add New Keyboard → Nasar Flow**, then
tap it again and turn on **Allow Full Access** (required - a keyboard needs it
to be allowed to open another app at all).

## Requirements

- iOS 17.0+ (SwiftData and the `@Observable` macro both require it)
- ~1-2GB free space once you've downloaded the models you use
- A paid Apple Developer account, only for TestFlight distribution

## Repository layout

```
MultilingualWhisper/          Swift sources (app target)
MultilingualWhisperTests/     Unit tests (language classifier, models)
vendor/whisper.cpp/           git submodule, pinned upstream
scripts/                      Python scripts to convert HF models to GGML
project.yml                   XcodeGen spec - generates the .xcodeproj, not checked in
exportOptions.plist           Template for signed archive export (release.yml fills it in)
.github/workflows/ci.yml      Unsigned Simulator build + unit tests, every push
.github/workflows/release.yml Manual signed archive + TestFlight upload
```

The `.xcodeproj` is generated, not committed - see `.gitignore`. This is
deliberate: a hand-maintained `.pbxproj` is one of the easiest things to corrupt
or merge-conflict in a repo nobody opens in Xcode directly. [XcodeGen](https://github.com/yonaskolb/XcodeGen)
regenerates it from `project.yml` on every CI run (`xcodegen generate`).

## Getting started

```bash
git clone --recurse-submodules <your-fork-url>
cd MultilingualWhisper
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

Everything else - installing XcodeGen, building `whisper.xcframework`, generating
the project, compiling, testing - happens in [ci.yml](.github/workflows/ci.yml) on
every push to `main` and on every PR, using GitHub's free macOS runners. Push to a
fork and watch the Actions tab.

If you ever do have a Mac available: `brew install xcodegen`, then
`vendor/whisper.cpp/build-xcframework.sh` (needs Xcode + cmake), then
`xcodegen generate`, then open `MultilingualWhisper.xcodeproj`.

## Before this can actually transcribe anything

Three things need your own values, none of which this repo can supply:

### 1. Bundle ID

Default is `com.multilingualwhisper.app`, set in **two** places that must match:
`project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`) and `exportOptions.plist`
(the key under `provisioningProfiles`). Change both if you change it.

### 2. Model files

Already done for this repo, as of 2026-09-06 - `Constants.modelRemoteURLs` points
at real, converted, verified models:

- **Singlish**: `jensenlwt/whisper-small-singlish-122k`, converted and hosted as
  a [GitHub Release asset](https://github.com/aarif86/MultilingualWhisper/releases/tag/models-v1)
  on this repo.
- **Arabic**: `oddadmix/whisper-small-arabic-dialectal` - colloquial/dialectal
  Arabic (amiyah), not Modern Standard/Quranic Arabic. Its own model card
  describes it as private/internal with ~43% WER / ~15% CER on its own
  held-out test set - workable, not highly accurate; validate against your
  own real-world audio before relying on it. Also a Release asset here.
- **English / Multilingual**: point straight at whisper.cpp's own pre-converted
  stock models on Hugging Face (`ggerganov/whisper.cpp`) - no conversion or
  rehosting needed. These two have no checksum in `Constants.modelChecksums`
  (verifying one means downloading the whole ~465MB file just to hash it,
  which wasn't worth it for a fallback model) - `ModelDownloadService` simply
  skips verification for any model with no checksum on file.

If you fork this and want your own models: `pip install torch transformers
numpy`, install `git-lfs`, then `python3 scripts/convert_singlish_model.py`
(and/or `convert_arabic_model.py`). These wrap whisper.cpp's own
`models/convert-h5-to-ggml.py` - **check the comment at the top of each script**
for the exact HF model IDs currently in use and why, since fine-tune
availability drifts over time. Some HF repos only ship the newer unified
`tokenizer.json` instead of the `vocab.json` that `convert-h5-to-ggml.py`
expects - if you hit `FileNotFoundError: vocab.json`, regenerate it with
`AutoTokenizer.from_pretrained(model_dir).get_vocab()` and write that out as
`vocab.json` (an empty `{}` for `added_tokens.json` is fine too - the script
loads it but never actually uses it). Then host the resulting `.bin` wherever
you like (a GitHub Release works well, free up to 2GB/file) and update
`Constants.modelRemoteURLs` / `Constants.modelChecksums`.

Before trusting a freshly-converted model at all, sanity-check it actually
works: download a [prebuilt whisper.cpp CLI release](https://github.com/ggml-org/whisper.cpp/releases)
for your platform and run it against a real audio sample (whisper.cpp ships
`samples/jfk.wav` for exactly this) - a clean conversion exit code alone
doesn't prove the weights or vocab came through correctly.

### 3. Apple signing, for TestFlight only

`ci.yml` needs none of this - it only ever builds for the Simulator. `release.yml`
(manual trigger, "Run workflow" in the Actions tab) needs these repo secrets:

| Secret | What it is |
|---|---|
| `APPLE_TEAM_ID` | Your 10-character Apple Developer Team ID |
| `APPLE_DISTRIBUTION_CERTIFICATE_BASE64` | `base64 -i Certificates.p12 \| pbcopy` of your exported Apple Distribution cert |
| `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` | The password you set when exporting that `.p12` |
| `APPLE_PROVISIONING_PROFILE_BASE64` | `base64 -i YourProfile.mobileprovision \| pbcopy` for an App Store profile matching the bundle ID |
| `CI_KEYCHAIN_PASSWORD` | Any random string - just needs to exist, used for a throwaway CI keychain |
| `APPLE_API_KEY_ID` | From an App Store Connect API key (Users and Access → Integrations) |
| `APPLE_API_ISSUER_ID` | Same page as above |
| `APPLE_API_KEY_BASE64` | `base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy` of that key's downloaded file |

If you've added the keyboard extension (see [Keyboard extension](#keyboard-extension)
below), two more are needed:

| Secret | What it is |
|---|---|
| `APPLE_PROVISIONING_PROFILE_BASE64` | **Re-generate and replace this one** - the main app's App ID now needs the App Groups capability, so its existing profile is stale until re-downloaded |
| `APPLE_KEYBOARD_PROVISIONING_PROFILE_BASE64` | A *second*, separate profile for the `com.multilingualwhisper.app.keyboard` App ID |

`release.yml` has successfully archived, signed, exported, and uploaded a build
to TestFlight from this exact codebase (as of 2026-09-06) - it follows Apple's
documented manual-signing CLI flow (import cert into a temporary keychain,
archive with `CODE_SIGN_STYLE=Manual` + an explicit `CODE_SIGN_IDENTITY`, export
a plain `.ipa`, then `xcrun altool --upload-app` with the API key). Getting
there took several real fixes worth knowing about if you fork this and hit the
same thing: macOS's `base64` needs `-D`, not GNU's `--decode`; `CODE_SIGN_STYLE=Manual`
alone isn't enough, you need `CODE_SIGN_IDENTITY="Apple Distribution"` too, or
Xcode defaults to looking for a Development cert; and `CFBundleVersion` /
`CFBundleShortVersionString` in `project.yml` must reference
`$(CURRENT_PROJECT_VERSION)` / `$(MARKETING_VERSION)` rather than hardcoded
literals, or bumping the build number at archive time (this repo's `release.yml`
uses `${{ github.run_number }}`) silently does nothing and App Store Connect
rejects the upload as a duplicate build.

## Known limitations

Explicit simplifications in this first cut, in rough order of how much they matter:

- **Language classifier is rule-based, not a trained model.** Arabic Unicode-block
  detection + curated keyword lists (Malay, Singlish, and common romanized
  Arabic/Islamic phrases) - not the fastText model the original idea called for.
  Training and shipping a real classifier is a separate project with its own
  labeled data; `LanguageClassifying` is a protocol specifically so a real model
  can drop in later without touching call sites.
- **VAD is energy-threshold, not learned.** Good enough to auto-stop a recording
  after silence; won't distinguish speech from other sustained noise the way a
  model like Silero VAD would. whisper.cpp actually has native VAD support
  (`whisper_full_params.vad`) that isn't wired up here, to avoid requiring a second
  model download for v1.
- **Model downloads don't survive the app being killed mid-download.** They do
  resume correctly if you background the app or a transfer fails and you retry
  (`URLSessionDownloadTask` resume data) - but this isn't a full
  `URLSessionConfiguration.background` session, so a force-quit mid-download starts
  over.
- **`PrivacyInfo.xcprivacy`'s reason code should be double-checked.** It declares
  `NSPrivacyAccessedAPICategoryUserDefaults` (for `AppSettings`) with reason code
  `CA92.1` - cross-check that's still current against Apple's
  [required reason APIs](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
  page before submitting to the App Store.
- **`exportOptions.plist`'s `method` value** (`app-store-connect`) is confirmed
  working against Xcode 26.6 as of 2026-09-06 - if a much later Xcode version
  rejects it, check `xcodebuild -help` on whatever version your runner has.

## Credits & Prior Art

The Singlish and Arabic models actually in use are credited inline in
[Model files](#2-model-files) above. This section is different: research and prior
art that shaped this app's thinking on code-switching, without (yet) being code or
weights actually shipped here. Full write-up: `docs/code-switching-research.md`.

- **[Mesolitica](https://github.com/mesolitica)** (Malaysia) — their
  `malaysian-whisper-*` and `finetune-whisper-small-ms-singlish-v2` models are the
  closest existing open fine-tunes to this app's Malay/Singlish code-switching
  target. Worth evaluating as a future upgrade once their exact license is confirmed
  and the conversion has been validated against real audio.
- **A\*STAR I2R / IMDA** — the National Speech Corpus and its MNSC (Multitask
  National Speech Corpus) re-release are real Malay/Mandarin/Tamil↔English
  code-switching data under the Singapore Open Data Licence, likely richer
  code-switch coverage than whatever subset this app's current Singlish model
  was tuned on.
- **[ahmedheakl](https://huggingface.co/ahmedheakl) / the ArzEn-LLM project** —
  `arazn-whisper-medium` (MIT licensed), a clean, ready-to-credit Arabic-English
  code-switching fine-tune, one size class up from this app's current Arabic model.
- **[whisper.cpp](https://github.com/ggml-org/whisper.cpp) community** — its own
  [discussion #598](https://github.com/ggml-org/whisper.cpp/discussions/598) on
  code-switching confirms the only known workaround (seeding a bilingual text
  prompt) is the same `initial_prompt` mechanism already in this codebase, just
  for a different purpose than the one currently disabled.

No Arabic+Malay code-switching model or dataset was found anywhere in this
research — a genuine, confirmed gap in the open-source ecosystem, not something
this list failed to look hard enough for.

## License

MIT - see [LICENSE](LICENSE).
