# Multilingual Whisper

An offline, on-device speech-to-text iOS app tuned for Singlish, Malay, and Arabic —
including everyday code-switching between them ("Bismillah, let's go makan lah").
Transcription runs entirely on-device via [whisper.cpp](https://github.com/ggml-org/whisper.cpp);
nothing is uploaded anywhere.

Built and maintained without a local Mac: all compiling, testing, and TestFlight
distribution happens on GitHub Actions' macOS runners.

## Status

This is a first, from-scratch implementation - complete and internally consistent,
but **it has never been compiled**. There is no Mac in this project's toolchain, so
the first real signal on whether it builds will be the [CI workflow](.github/workflows/ci.yml)
running on your fork. Expect at least one round of fixing compiler errors that
only show up on real Xcode. See [Known limitations](#known-limitations) below for
what's deliberately simplified for this first cut.

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

GGML models are 250MB-1GB+ each - too large to commit to git or bundle in the app.
`Constants.swift` ships with placeholder download URLs
(`modelRemoteURLs`) that **do not point anywhere real**. To fix that:

1. Convert a model: `pip install torch transformers numpy`, install `git-lfs`,
   then `python3 scripts/convert_singlish_model.py` (and/or
   `convert_arabic_model.py`). These wrap whisper.cpp's own
   `models/convert-h5-to-ggml.py` - **read the comment at the top of each script
   first**: the exact Hugging Face model IDs are worth double-checking, since
   "Singlish Whisper" and "Arabic Whisper" fine-tunes exist under more than one
   namespace on the Hub and availability drifts over time.
2. Host the resulting `.bin` file somewhere with direct-download links. A GitHub
   Release on this repo works well and is free up to 2GB/file.
3. Update `Constants.modelRemoteURLs` (and ideally `Constants.modelChecksums` -
   SHA-256 of the file; `ModelDownloadService` will refuse a download that doesn't
   match, once a checksum is present).

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

`release.yml` has never run against real credentials from this codebase - it
follows Apple's documented manual-signing CLI flow (import cert into a temporary
keychain, archive with `CODE_SIGN_STYLE=Manual`, export a plain `.ipa`, then
`xcrun altool --upload-app` with the API key). Budget time to debug the first run
against your actual team/profile.

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
- **No app icon artwork.** `Assets.xcassets/AppIcon.appiconset` has the modern
  single-size (1024×1024) slot wired up structurally; you need to actually supply
  the image.
- **`PrivacyInfo.xcprivacy`'s reason code should be double-checked.** It declares
  `NSPrivacyAccessedAPICategoryUserDefaults` (for `AppSettings`) with reason code
  `CA92.1` - cross-check that's still current against Apple's
  [required reason APIs](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
  page before submitting to the App Store.
- **`exportOptions.plist`'s `method` value** (`app-store-connect`) is current as of
  writing but Apple has renamed this key's accepted values before - if
  `-exportArchive` rejects it, check `xcodebuild -help` on whatever Xcode version
  your runner has.

## License

MIT - see [LICENSE](LICENSE).
