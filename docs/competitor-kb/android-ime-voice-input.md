# Android on-device voice-input IMEs: FUTO Voice Input, Transcribro, Sayboard, Gboard baseline

> The direct prior art for `NasarFlowAndroid`. All three open-source competitors chose the **IME route**, none use AccessibilityService injection, and FUTO documents the exact microphone-permission pattern an IME must use.

## 1. FUTO Voice Input

Sources: https://github.com/futo-org/voice-input (canonical: gitlab.futo.org/keyboard/voiceinput), https://github.com/futo-org/voice-input-models, https://github.com/futo-org/whisper-acft, https://deepwiki.com/futo-org/voice-input, https://deepwiki.com/futo-org/voice-input/5.3-keyboard-compatibility, https://deepwiki.com/futo-org/voice-input/6.2-setup-and-onboarding, https://voiceinput.futo.tech/, https://docs.keyboard.futo.tech/troubleshooting/faq

**Architecture — dual integration, standalone app:**
1. Handles the `android.speech.action.RECOGNIZE_SPEECH` implicit intent (floating window centred on screen) for any app/keyboard using the generic speech API.
2. Is also an **IME with a "voice" subtype** (`VoiceInputMethodService`, full `InputMethodService`) that other keyboards can switch to; it appears in the bottom half of the screen in place of the keyboard.

FUTO says development "has largely shifted focus to the FUTO Keyboard app, which has voice input built in" — voice-as-a-feature inside their own keyboard is the flagship; the standalone app serves other keyboards.

**Compatibility matrix:** works via voice-subtype with FUTO Keyboard, HeliBoard, FlorisBoard, AnySoftKeyboard, Unexpected Keyboard (v1.23+), AOSP Keyboard. Grammarly / SwiftKey "technically work" with an in-app privacy warning. **Incompatible: Gboard** (own closed voice system) and **Samsung Keyboard** (hardcoded to Samsung Voice Input or Google Voice Input). No accessibility fallback offered.

**RECORD_AUDIO from an IME — the key pattern:** the IME never requests the permission. Setup is gated through the companion app's normal `SettingsActivity` (`SetupOrMain` composable): `useIsMicrophonePermitted` → `checkSelfPermission(RECORD_AUDIO)` → `SetupEnableMic` screen (step 2 of 2) → `SettingsActivity.requestPermission()` shows the system dialog *from the Activity*. Tracks `askedCount`; after two denials redirects to `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`. Once granted it is live process-wide, so the IME service and the intent handler simply work.

**Engine:** whisper.cpp; migrated TFLite → GGML in March 2024 ("up to 6x faster", plus personal-dictionary support). Models restricted to **whisper tiny/base/small** (large "too big to run on most phones"); models must be **ACFT-finetuned** or clips <15s risk "infinite repetition or a long delay at the end". Only the 16 languages with >1,000 h of Whisper training data are exposed in the UI.

**ACFT (audio-context fine-tuning) — the latency fix:** Whisper pads to 30 s; whisper.cpp's `audio_ctx` shortens the encoder window but causes decoder repetition loops. ACFT fine-tunes the model so hidden states under dynamic context match the full-context reference (L2 loss). LibriSpeech WER at dynamic context: tiny.en **225.99% → 5.50%** (clean), **590.61% → 16.51%** (other); small.en **79.7% → 2.81%** (clean). Pretrained ACFT q8_0 variants: tiny(.en), base(.en), small(.en). Shipped in v1.3.2+. https://github.com/futo-org/whisper-acft

**Size / pricing / licence:** APK ≈ 70 MB (v1.3.6). FUTO Source First License 1.0 (non-commercial; payment code can't be removed). **Pay-what-you-want**, usage-based reminders, all features remain usable; one purchase covers Voice Input + Keyboard; no licence-key server ("I already paid" button) because it's fully offline. No ads/tracking; audio never saved or sent.

**Complaints / issues:** payment fails with network permission off (#155, #93); doesn't pause car media during recording (#140); won't start from Tasker with screen off (#106). FAQ tells users: bigger model for accuracy, Bluetooth headset mic for noise, contribute to Common Voice or fine-tune for your accent.

## 2. Transcribro

Sources: https://github.com/soupslurpr/Transcribro, https://github.com/soupslurpr/Transcribro/issues, https://privacytools.io/app/transcribro

- "Private and on-device speech recognition keyboard and service for Android": both a **voice IME** and a system **`RecognitionService`** (can be set as OS default so other apps' speech requests route through it).
- Engine: **whisper.cpp + Silero VAD** (auto-stop on silence). **English-only** (multilingual tracked in #18). Model size not published.
- Licence ISC. Free, no account, distributed via **Accrescent** + GitHub releases with signing-cert SHA-256; not on Play. Package `dev.soupslurpr.transcribro`. Matrix community.
- Health: ~745 stars, 21 open issues, last commit ~1 yr old ("development appears to be slowing"). #81 "rewrite the project as needed" is priority-max.
- Bugs worth pre-empting in Nasar Flow Android: **#96 unwanted leading space after transcription**; **#94 breaks when system animations are disabled**; **#85 transcription stops if device rotates mid-dictation**; #68 keep screen on while recording; #104 UI too large, obscures content; #84 customisable auto-stop delay; #53 processing indicator; #52 audio-feedback volume control; #102 wants SenseVoice/Paraformer via sherpa-onnx.
- Positioning: privacytools.io's "hardened pick" — "nothing else comes close" for private on-device dictation.

## 3. Sayboard

Sources: https://github.com/ElishaAz/Sayboard, https://f-droid.org/packages/com.elishaazaria.sayboard/, fork https://github.com/aberja/sayboard

- **Vosk (Kaldi)-based, not Whisper.** Genuine IME (not accessibility). Vosk model downloaded separately in-app or from alphacephei.com/vosk/models.
- Permissions: RECORD_AUDIO, INTERNET (model download only), POST_NOTIFICATIONS, FOREGROUND_SERVICE, and **QUERY_ALL_PACKAGES** ("due to a bug in Android" for `RecognitionService` integration, v4.2.0+) — a Play-scrutinised permission and friction point.
- APK 10–12 MiB per ABI (model separate). GPLv3. v4.2.1 (Sept 2024). Min Android 6. Weblate-translated.

## 4. IME vs AccessibilityService — the landscape fact

- **IME path (Google's sanctioned pattern):** Google's 2011 "Add Voice Typing To Your IME" post: `VoiceRecognitionTrigger` in `InputMethodService#onCreate()`, mic button shown only if `isInstalled()`, `startVoiceRecognition()` on tap, `onStartInputView()` hook inserts the pending result into the focused `InputConnection` via `commitText()`. Recognition runs in a separate Activity/Service *outside* the IME process, so the IME never needs the mic permission dialog. https://android-developers.googleblog.com/2011/12/add-voice-typing-to-your-ime.html
- **AccessibilityService path:** `AccessibilityNodeInfo.ACTION_SET_TEXT` on the focused node of any app without switching keyboards. This is the capability banking trojans (SharkBot, Xenomorph, Vultur, TeaBot…) abuse; Google warned in late 2017, required a declaration form from Nov 2021 (Android 12+ targets), and by 2026 largely restricts it to apps whose core purpose is accessibility. https://www.malwarebytes.com/blog/mobile/2026/03/google-cracks-down-on-android-apps-abusing-accessibility
- **Nobody credible in this space uses the accessibility shortcut.** FUTO, Transcribro, Sayboard all ship a real IME and/or the `RECOGNIZE_SPEECH` contract.

## 5. Gboard voice typing (baseline)

Sources: https://support.google.com/gboard/answer/2781851, https://support.google.com/gboard/answer/11197787

- Mic button at the top of the keyboard (tablets: movable voice toolbar). Tap → "Speak now" → dictate; can keep typing while mic listens.
- Spoken punctuation: "period", "comma", "question mark", "exclamation point", "new line", "new paragraph" — layered on auto-punctuation. Editing: "delete", "clear"; voice emoji.
- Advanced voice typing gated to **Pixel 6+** (Tensor). Closed integration: does not expose `RECOGNIZE_SPEECH` or voice-IME subtypes, hence incompatible with third-party voice input.

## Takeaways for NasarFlowAndroid

1. [steal] **Request RECORD_AUDIO from the companion Activity during onboarding, never from the IME.** Track denial count; after 2 denials deep-link to app details settings.
2. [steal] **Expose the voice IME subtype + handle `RECOGNIZE_SPEECH`** so HeliBoard/FlorisBoard/etc. users can invoke Nasar Flow from their existing keyboard — instant distribution without replacing anyone's keyboard.
3. [steal] **Ship a `RecognitionService`** (Transcribro) so Nasar Flow can be the system default speech recogniser.
4. [beat] **Dynamic `audio_ctx` + ACFT-style fine-tune** of the Singlish/Malay/Arabic small models — FUTO's numbers show naive `audio_ctx` shortening is catastrophic without fine-tuning, but with it short dictations get dramatically faster on low-end phones.
5. [steal] Restrict UI language list to models you can stand behind; keep tiny/base/small only.
6. [steal] Pre-empt Transcribro's bug list: leading-space handling, rotation mid-dictation, animations-disabled, keep-screen-on, auto-stop delay setting, processing indicator.
7. [beat] Samsung Keyboard and Gboard hard-block third-party voice IMEs — the only way onto those users' phones is being the full keyboard, which is what Nasar Flow already is.
8. [steal] FUTO's honest offline monetisation ("I already paid" button, no licence server) is a trust asset for an offline-first app.
