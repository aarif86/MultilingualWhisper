# Contributing to Multilingual Whisper

## Workflow

1. Fork the repo, create a branch.
2. Make your change.
3. Push - `ci.yml` runs automatically (unsigned Simulator build + unit tests, no
   Apple account needed).
4. Open a PR once CI is green.

Nobody needs a Mac to contribute code: GitHub Actions does the compiling. You do
need one to actually run the app on a device or simulator and see it work.

## Testing

- `MultilingualWhisperTests` covers the language classifier and the data models -
  pure logic, no device/model files needed, runs in CI.
- Audio capture, whisper.cpp integration, and model downloading are not unit
  tested (they need a real microphone, a real device/simulator, and multi-hundred-MB
  model files) - these need manual testing on-device. If you touch
  `AudioService`, `WhisperEngine`, or `ModelDownloadService`, say in your PR what
  you tested manually and on what.

## Adding a language

1. Find (or fine-tune) a whisper-small-or-larger checkpoint for it.
2. Add a case to `WhisperModelType` (`LanguageTypes.swift`) with its display name,
   local filename, and language hint.
3. Add a conversion script under `scripts/`, following the pattern in
   `convert_arabic_model.py`.
4. Add its remote URL to `Constants.modelRemoteURLs` once you've hosted the
   converted file.
5. If it needs its own keyword list for `LanguageClassifier`, add one to
   `Constants.swift` and wire it into `RuleBasedLanguageClassifier.classify`.

## Code style

- No inline comments explaining *what* code does - names should do that. Comments
  are for non-obvious *why* (a constraint, a workaround, an invariant).
- Follow the existing MVVM split: Views own layout and `@State` view models;
  view models own presentation state and orchestration; Services own one piece of
  system/engine integration each (audio, download, persistence, the whisper
  engine itself).
