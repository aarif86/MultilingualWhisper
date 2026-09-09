# Mobile keyboard flows: Wispr Flow, Willow, Superwhisper, Aqua Voice, Typeless (iOS + Android)

> How each desktop leader handles the phone, and specifically how each works around Apple's ban on microphone access from keyboard extensions. Android IME/open-source detail is in [android-ime-voice-input.md](android-ime-voice-input.md).

## 1. Wispr Flow — iOS

**Setup (docs.wisprflow.ai):** Settings → General → Keyboard → Keyboards → Add New Keyboard → Wispr Flow → **Allow Full Access** → globe key in any field → tap mic. "Full Access is required for transcription"; without it "the keyboard cannot record audio or reach transcription." https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone · https://docs.wisprflow.ai/articles/3152211871-setup-guide

**Mic-ban workaround:** "Keyboard extensions can't show iOS permission dialogs, so the prompt has to come from the main app." The container app's onboarding triggers the OS mic dialog once. If revoked, the keyboard itself shows *"To use Flow, turn on Microphone in Settings"* with a **Go to Settings** button. Cloud pipeline: "Flow requires an internet connection for voice transcription." https://docs.wisprflow.ai/articles/4351452717-troubleshooting-mic-issues · https://docs.wisprflow.ai/articles/2772472373-what-is-flow

**Capture model:** not live-partial. "Captures audio while you hold the hotkey [or mic button], then transcribes and pastes the finished text on release" — the "full-context approach" is what lets it clean fillers, punctuation and self-corrections.

**Keyboard UI:** mic button; **Writing-Style Pill** (tap to switch tone, applies immediately); Undo/Redo in the top bar; **"Add to Dictionary" pill** for capturing a word mid-session. Main app tabs: Home (history), Dictionary, Snippets, Style, Scratchpad/Notes. https://docs.wisprflow.ai/articles/5096240724-navigating-the-wispr-flow-app-desktop-ios-and-android

**Entry points:** Live Activity widget; Control Center widget toggling recording; Notes lock-screen + Control Center widgets; **Action Button** guided setup (Settings → Action Button → Shortcuts → Flow shortcut) — "dictated text from a shortcut is inserted straight into the text field rather than returned to Shortcuts or the clipboard" when the Flow keyboard is active; **Back Tap**; Siri phrases: "take Flow note", "dictate with Flow", "quick dictate with Flow", "dictate to clipboard with Flow", "quick dictate to notes with Flow", "turn on/off Flow". No Apple Watch app. https://docs.wisprflow.ai/articles/4500510662-set-up-the-action-button-for-flow-on-iphone · https://docs.wisprflow.ai/articles/1986921789-how-to-set-up-flow-shortcuts-for-iphone

**Notes/Scratchpad:** cloud-synced; disabled under HIPAA/ZDR org policy; iOS + desktop only, not Android.

**Pricing:** Pro **$15/user/mo or $12/mo annual** (Aug 2026). Free: **2,000 words/week desktop, 1,000 words/week iPhone, unlimited on Android (promo)**. Pro = unlimited + Command Mode + team. 14-day trial, no card. 50% student/educator. https://wisprflow.ai/pricing

**Languages:** 100+ incl. Hindi, Hinglish, Arabic; on-the-fly detection/switching. https://wisprflow.ai/india

**Complaints (App Store / Trustpilot 2.7):** "Every time you use it, the app has to reopen and you need to swipe over multiple times"; transcription failures "five or six times, losing important work… costing me intellectual property"; "keeps losing my transcription every time I do something long-form, especially when I'm using my AirPods"; processing loop after checkmark; correction requires switching to the number/punctuation keyboard which "is not nearly as responsive as the phone's normal keypad"; "reliability drops after the 14-day trial". https://apps.apple.com/us/app/wispr-flow-ai-voice-keyboard/id6497229487?see-all=reviews · https://spokenly.app/blog/wispr-flow-review

## 2. Wispr Flow — Android

**Not an IME.** Accessibility-service overlay: a floating **"Flow Bubble"** above the existing keyboard; tap (or long-press for push-to-talk) records and injects text via AccessibilityService. https://docs.wisprflow.ai/articles/8858845757-setup-wispr-flow-on-android-android-settings

**Setup flow:** Play install → sign-in (Google/Apple/Microsoft/SSO/email) → language → tap-to-dictate and push-to-talk tutorials → **Display over other apps** → **Accessibility** (legal consent screen; enable the main toggle, *not* the "shortcut" toggle, or you get *"Oops, something isn't right"*; toggle location varies: Samsung "Installed apps", Xiaomi extra dialog, Pixel/OnePlus "Downloaded apps") → data-safety preference → **battery-optimisation exemption** → **notification permission** (Android 13+, mandatory) → done. https://docs.wisprflow.ai/articles/7669452251-accessibility-permission-on-android · https://docs.wisprflow.ai/articles/2809924024-android-download-installation-guide

**Contrast:** Android never needs the bounce-to-container trick; accessibility + overlay + RECORD_AUDIO suffices. But Google Play repeatedly re-questions this permission set. https://docs.wisprflow.ai/articles/1842649381-why-does-google-play-keep-asking-about-wispr-flow-permissions

## 3. Willow — iOS (fetched via curl; site 403s WebFetch)

**Three permissions, requested automatically in onboarding:** Microphone; Keyboard (registers as a system keyboard); **Allow Full Access** — needed to "process your dictation and insert text into the app you're using", "trigger voice input from within the keyboard", and "let the keyboard respond and update instantly during dictation." Without it "Willow can appear, but it won't be able to perform voice typing reliably." Fallbacks: Settings paths; if keyboard missing, force-quit target app, reopen, hold globe. https://help.willowvoice.com/en/articles/12845807-setting-up-permissions-on-ios-keyboard-access-full-access-microphone

**The mic-ban workaround — best public explanation found anywhere:** *"Apple does not allow any third-party app or keyboard to start using the microphone in the background unless the app is active first. So before Willow can power dictation inside another app, it must quickly: Open Willow → Turn on the background microphone session → Then let you return to the app you want to write in."* Described as "a safe and approved workaround that follows Apple's rules." Once the background session is live the user is **not bounced again** — they tap the keyboard mic directly across apps until the session times out or is killed. Three ways to end it: tap the Live Activity banner and toggle off; open Willow and tap the green mic toggle top-right; swipe-quit the app. A **yellow microphone indicator / "On" Live Activity / Dynamic Island badge** stays visible the whole time. Rationale: "Without this step, Willow would only work inside the Willow app, which would remove most of the value." https://help.willowvoice.com/en/articles/12855752-why-am-i-taken-back-to-the-willow-ios-app-before-i-can-dictate

→ **This is exactly Nasar Flow's `FlowSessionEngine` design.** Willow validates it as the category-standard approach and shows the polish that's missing: Live Activity with an off toggle, a green in-app mic toggle, and copy that explains *why*.

**Full keyboard for editing:** Willow ships a complete QWERTY layout alongside voice, so users "make quick edits… rather than typing them out" — directly answering Wispr's "switch keyboards to correct" complaint. https://apps.apple.com/us/app/willow-ai-voice-dictation/id6753057525

**Pricing:** Free 2,000 words/week. Individual **$15/mo or $144/yr**; Team Pro **$12/user/mo** (3-seat min, 20% off annual); Enterprise custom. Model tiers named **Frontier Pro** (smartest) vs **Frontier Mini** (weaker); "Unlimited Scribe usage"; shared team dictionary. https://help.willowvoice.com/en/articles/12854184-willow-pricing-plans-overview

**Complaints:** "The keyboard is incredibly buggy" — autosuggest interferes with mid-sentence edits; "middleware failure", crashes, lost data; un-disableable inactivity notification; free-tier caps; imperfect non-English. https://www.getvoibe.com/resources/willow-voice-review/

## 4. Superwhisper — iOS

**On-device model tiers (their names → sizes):** Fast 75 MB · Nano 150 MB · Standard 500 MB · Pro 1.5 GB · Ultra V3 Turbo 1.6 GB (+ Chinese variant) · Ultra 3 GB · **Parakeet** 476 MB (EN) / 494 MB (multilingual). Cloud: S1-Voice, Ultra cloud, Deepgram Nova 3 / Nova 2 / Nova Medical. https://superwhisper.com/docs/models/voice.md

**Modes:** Super, Message, Email, Note, Meeting, Custom. Custom Mode = your own instructions + three context toggles (application context, copied text, selected text). Docs warn "Instructions are empty by default… AI will not know what task to perform" and recommend XML-tag structure (role/instructions/requirements/context/style/output-format) plus 2–3 example pairs. https://superwhisper.com/docs/modes/custom.md

**Pricing:** $8.49/mo · $84.99/yr · **Lifetime $249.99**. Free = basic transcription + limited cloud models (no local models, 3 custom modes). https://superwhisper.com/docs/get-started/sw-pro.md

**iOS keyboard reliability:** "dictation apps must switch between the keyboard and the dictation app"; "in some apps it records but doesn't paste the dictated text in, while in others it switches over to Superwhisper and gets stuck there." https://eiiis.substack.com/p/superwhisper-ios-keyboard

**Complaints (App Store):** keyboard "randomly deletes a word you just typed or inserts a word you never typed"; fails to paste back / stuck in dictation UI; "doesn't stay in the app that you're trying to use"; **25%+ battery drain and overheating from three short uses**; "insists on supplying all of its own punctuation" with no override; not all Mac languages available in the iOS keyboard (79+ upvotes); can't switch Modes mid-session; Pro upsells heavier in keyboard. https://apps.apple.com/us/app/superwhisper-ai-dictation/id6471464415?see-all=reviews

## 5. Aqua Voice — iOS

**Flow:** "Install the Aqua Voice keyboard, open any app, tap the mic and talk." iOS 17+. Claims <50 ms processing, final text ~450 ms after speech ends, up to 230 WPM. https://apps.apple.com/us/app/aqua-voice-ai-dictation/id6759074969

**Differentiators:** **Avalon** proprietary ASR (claims to beat Whisper large-v3 on 7/8 OpenASR sets, 97.4% on their "AISpeak" jargon benchmark vs 51.5% Canary 1B); **Deep Context** (client-side engine reads on-screen content to bias names/code); **Edit Mode** — speak commands on the last transcript or selection: "Remove filler words, this is a Slack message", "Translate this to Japanese", "Make this title case", "make this a list", "rephrase that", "redo the second sentence" — no fixed syntax. https://aquavoice.com/blog/introducing-avalon · https://aquavoice.com/llms.txt

**Guide structure:** Features (File Tagging, Edit Mode, Replacements, Languages, History, Custom Instructions, Dictionary); Guides (multiple activation keys, Avalon, hide dock icon, Recommended Microphones, fix microphone delay); Trust & Security (SOC 2 Type II). https://aquavoice.com/guide

**Pricing (conflicting):** web reviews say Pro $8/mo or $96/yr, 70% student; App Store shows **Pro $12.99/mo or $119/yr; Max $39.99/mo or $374.99/yr**. Free = one-time 1,000 words. Verify before quoting. iPhone keyboard launched April 2026 on Avalon 1.5. 4.4/5 (83 ratings).

**Mic-ban mechanism:** not documented publicly.

## 6. Typeless — iOS

**Positioning:** strips fillers, removes repeated words, honours self-corrections ("keep only the intended final phrasing"); "6× faster than typing"; "the only major AI-enhanced dictation app with native Android support." https://www.typeless.com/

**Features:** "Speak to edit"; auto-formatting lists; 100+ languages with mixing; personal dictionary; app-aware tone; cloud sync (v2.5.0+). FAQ confirms Accessibility + Microphone permissions but not on-device vs cloud, nor the iOS mechanism. https://www.typeless.com/help/faqs

**Pricing:** Free **8,000 words/week** (standard accuracy); Pro **$30/mo or $144/yr**; 30-day full-Pro trial auto-converting to Free. 4.5/5 (671 ratings). Complaints: keyboard hard to keep active, screen-lock bug in background, early cut-offs on long dictations. https://usevoicy.com/blog/typeless-pricing

## Cross-app comparison: how each survives Apple's keyboard-mic ban

| App | Mechanism | Visible indicator | Session persistence |
|---|---|---|---|
| Wispr Flow | Container app grants mic once; per-utterance capture; cloud round-trip on release | none documented | per-dictation |
| **Willow** | Container app foregrounded once to open a **background microphone session**; keyboard then starts/stops that session | yellow mic + "On" Live Activity / Dynamic Island | persistent until timeout / toggle / force-quit |
| Superwhisper | switch-to-container pattern; reported unreliable (stuck, no paste-back) | none documented | per-session, restart per Mode |
| Aqua Voice | undocumented | — | — |
| Typeless | undocumented (Accessibility + Mic) | — | — |
| Wispr Flow Android | AccessibilityService + overlay bubble + RECORD_AUDIO | Flow Bubble | persistent while permissions held |

## Best-practice takeaways

1. **Willow's session model is the category standard and matches Nasar Flow's Flow session.** Copy the polish: Live Activity / Dynamic Island "On" badge with a one-tap off, green in-app mic toggle, and an explainer article titled the way users ask the question ("Why am I taken back to the app?").
2. **Explain the bounce, don't hide it.** Both Wispr and Willow ship dedicated help articles for the app-switch; the complaint volume is about *unexplained* switching.
3. **Never lose a dictation.** The #1 mobile complaint across Wispr/Superwhisper/Willow is lost long-form transcriptions (AirPods, backgrounding, processing loops). Persist audio to disk before transcribing; keep the last N raw audios recoverable from History.
4. **Ship a real QWERTY inside the voice keyboard** (Willow) so corrections don't force a keyboard switch — Wispr's biggest keyboard complaint.
5. **Keyboard chrome that earns its place:** style pill, undo/redo, "Add to Dictionary" pill (Wispr).
6. **Multiple entry points beyond the keyboard:** Action Button, Back Tap, Control Center, Lock-screen widget, Siri Shortcuts with named phrases (Wispr). Nasar Flow has none.
7. **Free tier in words/week, not minutes** is the norm (1,000–8,000). An offline app can make "unlimited" its price-list headline.
8. **Battery/heat is a live complaint** for on-device (Superwhisper iOS). Publish a battery figure per model tier and default to the smallest model that hits the accuracy bar.
9. **Tier-name your models by outcome** (Fast/Nano/Standard/Pro/Ultra; Frontier Mini/Pro), not by whisper size names.
10. **Edit-by-voice on the selection** (Aqua Edit Mode, Typeless Speak-to-edit) is now expected in the top tier; command phrasing is natural language, not a grammar.
11. **Punctuation override** — users hate forced auto-punctuation with no toggle (Superwhisper).
12. **Mode cannot change mid-session** is a complaint; make style switchable without restarting the Flow session.

## Ideas Nasar Flow should steal or beat

1. [steal] Live Activity + Dynamic Island indicator for the Flow session with an off toggle. Willow-style help article.
2. [steal] Full QWERTY layer in `NasarFlowKeyboard` for corrections.
3. [steal] Style pill + undo/redo + Add-to-Dictionary pill in the keyboard top bar.
4. [steal] Action Button / Back Tap / Control Center / Lock-screen widget / Siri Shortcut entry points that call `nasarflow://dictate`.
5. [beat] Willow needs the network; Nasar Flow's Flow session works in a lift, on the MRT, in a mosque basement. Make "works offline in any app" the keyboard's headline.
6. [beat] Superwhisper's iOS keyboard drops languages; Nasar Flow can offer every model in the keyboard because it's the same engine.
7. [beat] Publish a "never lose a dictation" guarantee backed by on-disk audio + History recovery — nobody claims it.
8. [steal] "Speak to edit" on selection via the Flow session (selection text is available to the keyboard via `textDocumentProxy`).
