# Nasar Flow - iOS (MultilingualWhisper)

Offline on-device Singlish/Malay/Arabic dictation app (whisper.cpp). Shared product rules and brand: see the `nasarflow-hub` repo (sibling folder).

## Hard constraint: no local Mac
Everything builds on GitHub Actions. There is no Xcode here, so SwiftUI can't be compiled or screenshotted locally. Verify with CI logs and real-device feedback; say plainly what is unverified.

## Workflow
- Feature/fix on a branch -> PR -> CI green (`ci.yml`) -> merge -> release with `gh workflow run release.yml --ref main`.
- A UI test occasionally flakes ("Failed to terminate"); re-run the failed job on the same commit before assuming a real bug.
- Build number = GitHub Actions run number. Confirm uploads with the log lines `UPLOAD SUCCEEDED` + `Delivery UUID`, and processing via the App Store Connect API (`apple-signing/asc_api.js`, app id 6809156577; the builds endpoint can't sort/filter - use limit=200).
- With EVERY release, update the Status page and Testing Guide artifacts (links in the hub CLAUDE.md) in plain English, and say which build number to use and which are superseded.
- Parallel sessions use `.claude/worktrees/`; never `git checkout` a branch held by a worktree - make a differently named branch.
- Three provisioning profiles must exist as secrets: main, keyboard, widgets (plus a future Share extension profile).

## Design rules
- Mockup first, approval, then build. Real device reports beat assumptions.
- Colors live in `Utils/Theme.swift` (`Brand`). Gold has two roles: `goldDeep` (adaptive, text/tint) vs `goldSolid` (fixed, fills behind white content). Never use plain #B8932A as text (2.9:1). Compute WCAG contrast for any new color.
- Explicitly `.tint()` native controls; global AccentColor does not reliably reach all of them.
- Home uses a custom header (nav bar hidden), not toolbar items - iOS clips custom controls in toolbar capsules.
- Known open item: accessibility (Dynamic Type on `brandSerif`, VoiceOver grouping of stats, Reduce Motion on the record button, label for the "..." menu).

## Language classifier
Keyword sets in `Utils/Constants.swift` plus user words in `UserLanguageKeywords`. Raw cleanup mode must stay a complete passthrough.
