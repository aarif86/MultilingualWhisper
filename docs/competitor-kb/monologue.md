# Monologue

> Made by Every (the media/software company behind Cora, Spiral, Sparkle, Proof); a voice dictation + voice notes + bot-free meeting-transcription app for Mac/iPhone/iPad/Apple Watch aimed at "high-taste" knowledge workers and AI power users who write a lot across many apps and languages.

## Facts
- **Maker / founded / funding:** Built by Every Inc. (media/software company, publishes at every.to; other products include Cora, Spiral, Sparkle, Proof). Monologue (Mac dictation) launched **September 16, 2025**. iOS app with "app-based formatting" launched **February 18, 2026**. Monologue Notes (bot-free meeting/voice-memo capture, MCP/API/CLI access) launched **April 21, 2026**. No funding/founding-round info found in crawled pages.
- **Platforms:** Mac, iPhone, iPad, Apple Watch, plus a web app for Notes (docs → "Web App" section). **No Windows, Android, or Linux app** — this is an Apple-only product, a real gap vs. Wispr Flow (which is cross-platform).
- **Pricing:**
  - Free: **1,000 words + 10 notes, lifetime one-time allotment** (not recurring/monthly) — roughly 8 minutes of natural speech per third-party review; widely called "the stingiest free tier in the category."
  - Pro monthly: **$15/month** regular rate (some sources still show an early-bird promo of **$9.99–$10/month**, explicitly flagged as promotional and likely to reset to $15 on renewal).
  - Pro annual: **$144/year** (~$12/month effective, ~20% off monthly).
  - Every bundle: **$30/month**, includes Monologue Pro + Cora + Spiral + Sparkle + Proof + Every's AI newsletter/camps/model reviews.
  - No lifetime/one-time-purchase tier, no BYOK (bring-your-own-API-key) option.
- **Engine:** Dual-mode, cloud-first.
  - **Remote/cloud (default):** audio sent to Monologue's servers; "generally provides the best accuracy." This is also where the LLM-based "smart formatting" cleanup happens.
  - **Local (optional, Apple Silicon Macs only):** downloadable on-device model does speech-to-text and can produce a raw transcript fully offline — but "smart formatting may still require a network connection," so local mode alone yields a rawer, lower-accuracy result. No specific model names (Whisper variant, custom, etc.) disclosed anywhere crawled, on either path.
  - **"Blazing Fast" mode:** explicitly skips the "normal smart post-processing path" — a named speed-over-polish setting, i.e. an exposed raw-vs-polished toggle.
  - **DeepContext:** optional screen-recording permission-gated feature; screenshots feed formatting decisions and are deleted immediately after processing.
- **Languages:** 100+ languages; Auto Detect is the default, or users can pin **up to 3 languages they regularly speak**. Code-switching mid-sentence is handled by pre-declaring all languages in play ("If you switch languages in one sentence, include both languages in the selection") — not true unconstrained per-word language ID. No translation feature found.
- **Docs / KB / blog / changelog URLs (25 pages crawled):**
  - https://www.monologue.to/
  - https://www.monologue.to/docs
  - https://www.monologue.to/docs/getting-started/first-dictation
  - https://www.monologue.to/docs/dictation/shortcuts
  - https://www.monologue.to/docs/dictation/languages-and-models
  - https://www.monologue.to/docs/dictation/mac-preferences
  - https://www.monologue.to/docs/personalize/modes-and-instructions
  - https://www.monologue.to/docs/personalize/dictionary
  - https://www.monologue.to/docs/account-and-privacy/permissions-and-privacy
  - https://www.monologue.to/docs/voice-notes/automatic-note-tagging
  - https://www.monologue.to/docs/voice-notes/record-a-note
  - https://www.monologue.to/docs/integrations/mcp
  - https://www.monologue.to/docs/iphone-and-ipad/keyboard-and-full-access
  - https://www.monologue.to/docs/iphone-and-ipad/action-button-and-shortcuts
  - https://www.monologue.to/docs/troubleshooting/language-and-unexpected-words
  - https://www.monologue.to/docs/troubleshooting/dictation-and-pasting
  - https://www.monologue.to/data-privacy
  - https://help.every.to/en/collections/19630952-monologue (migrated — now shows "Monologue Help Center Has Moved")
  - https://every.to/on-every/introducing-monologue-effortless-voice-dictation (launch post)
  - https://every.to/on-every/introducing-monologue-notes-record-every-meeting-call-and-voice-memo (Notes launch post)
  - https://www.getvoibe.com/resources/monologue-review/ (third-party review)
  - https://www.getvoibe.com/resources/monologue-vs-wispr-flow/ (third-party comparison)
  - https://www.getvoibe.com/resources/monologue-pricing/ (third-party pricing breakdown)
  - https://spokenly.app/comparison/monologue (third-party comparison)
  - https://alternativeto.net/news/2026/2/ai-dictation-tool-monologue-launches-ios-app-with-polished-output-and-app-based-formatting (news writeup)

## Activation & capture UX
- **Mac push-to-talk:** default shortcut is the **right-side Option key**. Hold to record, release to finish and auto-insert. Fully remappable to other modifiers, key combos, function keys, or supported mouse buttons.
- **Hands-free toggle:** independently-bound shortcut — tap once to start, tap again to stop.
- **Cancel dictation:** bindable shortcut, "stops the active recording without inserting a result."
- **Live mode switch:** pressing **right Shift** mid-recording opens a mode picker (Default / Blazing Fast / custom modes) without interrupting the recording.
- **Paste last transcript:** shortcut to reinsert the most recent result if the initial insert failed.
- **iOS:** switch to the Monologue keyboard (hold globe key → pick Monologue), tap the mic icon, speak, stop; text inserts at the cursor.
- **iOS Action Button:** guided setup at Settings → Action Button binds the **"Dictation to Clipboard"** Shortcuts action to the hardware Action Button (requires keyboard configured, mic access, and Live Activities permission). Press-and-hold to start, press-and-hold again to stop.
- **Shortcuts app integration:** searchable "Monologue" actions let users build custom automations (via Shortcuts app, widgets, Siri, or iOS Automations), including standard/custom dictation modes and a separate **"Record Note"** action for Voice Notes instead of returning text. Known limitation: Quick Dictation via Action Button/Shortcuts needs mic permission and does **not** respect the "Pause Other Audio" preference (background audio keeps playing during capture) — flagged explicitly in docs.
- **Recording feedback (Mac):** three indicator styles at Settings → Dictation → Indicator: **Classic** (full indicator at screen edge), **Mini** (compact, near the text cursor), or **None**; each configurable to show always or recording/processing-only, and Mini can be hidden per-app.
- **System behavior toggles:** Open on login, Prevent sleep (recommended for long hands-free sessions), Show dock icon, Creator mode, Support non-standard keyboards.
- **Meeting auto-detect:** Monologue can "remind you to start a Voice Note when a supported calling app begins using the microphone" (dismissible globally or per-app).
- Failed pastes aren't fatal — results persist in **History**.

## Text insertion
- Default path: automatic insertion into the focused text field once processing completes; requires the target app/field to still have focus and Accessibility permission granted (Mac) to "detect global shortcuts and insert text into other apps."
- **Known-broken behavior, explicitly documented:** if the active app or text target changes before processing finishes, or the field can't accept automated text, Monologue shows a **"Copied"** state instead of inserting — user must return to the field and press Cmd-V manually. Docs recommend testing in TextEdit/Notes first to isolate whether a given app is simply blocking programmatic insertion ("Some applications explicitly restrict programmatic text insertion").
- **"Support non-standard keyboards"** setting is an explicit fallback insertion path for incompatible layouts/apps — docs warn it "uses a different insertion path" and should be tried only after standard troubleshooting.
- A **clipboard fallback** can be enabled so a failed automatic insert always leaves the transcript ready to paste manually.
- iOS: text inserts via the custom system keyboard extension (Full Access permission required — Apple's standard third-party-keyboard warning applies). **iOS secure/password fields automatically revert to the native Apple keyboard** — Monologue cannot dictate into password fields; this is an iOS-level restriction, not a Monologue choice.
- History log preserves recent results even when a paste fails, so a lost target doesn't mean lost work.
- Dedicated troubleshooting page exists: "Dictation or pasting is not working" (https://www.monologue.to/docs/troubleshooting/dictation-and-pasting) — a strong signal that insertion failures are a common real support issue.
- *Discrepancy note:* one third-party comparison (spokenly.app) claims Monologue has "no custom iOS dictation keyboard" and "no MCP integration" — this directly contradicts Monologue's own docs (which describe both in detail) and should be treated as outdated/inaccurate third-party copy, not fact.

## Accuracy & personalization
- **Custom Dictionary** (Settings → Dictionary): manually add exact words, with optional separate spoken-form → written-form mapping when pronunciation and spelling diverge (jargon, brand names). Praised in third-party review as the standout accuracy feature ("top-notch accuracy especially with the custom dictionary").
- **Dictionary import** from competitors: **Aqua Voice, Wispr Flow, Superwhisper, and Willow Voice** dictionaries can be imported directly — a deliberate switching-cost reducer for users coming from rival apps.
- No auto-learning from corrections, no contact-list name import, no ML personalization found — the dictionary is a manual, curated list. Problem words are fixed by manually checking spelling/capitalization, removing conflicting entries, and (per troubleshooting docs) submitting thumbs-down feedback noting the intended language/output, while preserving the original recording as evidence.
- **DeepContext**: screen-content awareness (optional, permission-gated) used to inform formatting decisions app-by-app; screenshots deleted immediately after processing.
- **AU/UK English spelling toggle** exists as a dedicated personalization setting.
- Root causes of bad transcription per troubleshooting docs: wrong language setting, auto-detect misfiring, very short recordings, background speech, abrupt language switches (limited detection context), unrecognized specialized terms/names/abbreviations, or formatting artifacts from an active mode/instruction (test with no mode selected to isolate transcription vs. formatting issues).
- Local/on-device transcription is explicitly flagged by Monologue itself as lower accuracy than the cloud default — a rare admission that on-device quality trails cloud.
- Third-party marketing claims (via AlternativeTo writeup) position Monologue as more reliable than Apple's native dictation for **Indian accents** and in noisy environments — an accent-robustness claim worth noting, though unverified by Monologue's own docs.

## Formatting & AI cleanup
- Core pitch: destination-app-aware "smart formatting" — "Code in Cursor, full sentences in Gmail, casual in Slack. Monologue reads the room." iOS examples: short conversational messages in iMessage, structured paragraphs for email, organized lists/headings in Notes.
- Removes filler words and resolves mid-utterance self-corrections (only the corrected version survives in final output).
- Auto-handles punctuation, capitalization, paragraph breaks, numbered lists, sign-offs depending on mode/app.
- **Named Modes** = tone/format presets: **Messaging** (short, conversational), **Email** (turns fragments into a complete message), custom modes like a repeatable "Project-update" structure/terminology. Modes can auto-activate per app or domain (example given: chatgpt.com).
- **Blazing Fast mode**: explicit raw-vs-polished toggle, trading formatting quality for speed by skipping the smart post-processing path.
- **Auto Enter**: optionally simulates pressing send/submit right after processing — docs explicitly warn against this for email, forms, or anything needing a review step.
- Custom instructions are plain-language and outcome-focused; exact example given: *"Write a concise project update. Keep product names exactly as dictated and use bullets only when I list three or more items."* Guidance: start with one instruction, test live in your real workflow, add complexity only as issues recur.
- Access: on Mac via **Customization**; on iPhone/iPad via **Modes**; or right-Shift mode picker mid-dictation on Mac.

## Voice commands
- **No spoken command vocabulary exists.** Design philosophy stated directly in docs: "No command syntax required — speak naturally." There is no "delete that," "new line," "undo," or similar spoken phrase found in any crawled doc.
- Editing/control actions (cancel, paste-last, mode-switch) are all keyboard-shortcut-driven, not voice-driven.
- One third-party review vaguely claims Monologue "supports... voice commands," but this isn't corroborated by Monologue's own documentation and likely conflates Modes/workflows with literal spoken commands.

## Languages & multilingual
- 100+ languages, Auto Detect as default recommendation.
- Code-switching support is **declarative, not automatic**: users select up to 3 languages they expect to speak (including combinations), and are told explicitly to add every language they mix into one sentence — meaning true unconstrained free-form multilingual code-switch detection is not what's happening under the hood.
- No translation feature identified (transcribes in spoken language; "translate" in marketing copy appears to mean adapting tone/register across professional contexts, not literal machine translation).
- Very short recordings, background speech, and abrupt language switches are documented as reducing detection accuracy — i.e. rapid code-switching (exactly Nasar Flow's core use case) is called out as a known accuracy risk factor.

## Privacy & data
- **Dictation**: "Monologue does not save audio or transcripts from Dictation on its servers." AI providers process dictation "with zero data retention" — not retained for model training.
- **DeepContext** screenshots deleted immediately after processing.
- **Saved Voice Notes are the deliberate exception**: audio, transcript, and summary are retained in-account for cross-device sync and MCP/API/CLI access.
- Local/offline transcription only on Apple Silicon Macs; iOS dictation and cloud/remote mode always send audio (and DeepContext screen data) to Monologue's servers.
- Explicit user warning: don't dictate "passwords, authentication codes, API keys, or other secrets."
- **Settings → Data & Privacy**: delete local dictation transcripts/device data; opt in/out of whether transcripts are used to improve dictation quality; access ToS/privacy policy — separate from full account deletion.
- Permissions requested: Microphone; Accessibility (Mac — global shortcuts + text insertion); Screen Capture (Mac, optional — DeepContext / system audio for meetings); Full Access (iOS keyboard extension, Apple-mandated for any network-capable custom keyboard).
- No SOC2/HIPAA/enterprise-compliance claims found anywhere crawled — third-party comparison (getvoibe) explicitly notes "Compliance: None" for Monologue vs. Wispr Flow's "SOC 2 Type II, HIPAA." A docs link to an **Enterprise API** exists (https://www.monologue.to/docs/enterprise-api, not yet crawled in depth) suggesting a B2B track, but no compliance certifications are advertised.
- Meeting recording requires consent: docs explicitly instruct users to "make sure everyone involved knows that the conversation is being recorded and follow the laws and policies that apply to you."

## Onboarding & docs
- Doc site (monologue.to/docs) organized into 9 clear categories: **Start Here** (Mac/iPhone/iPad setup, first dictation, platform availability), **Dictation** (shortcuts, mics, languages/models, history, Mac indicators), **iPhone and iPad** (keyboard + Full Access, preferences/modes, Action Button/Shortcuts), **Personalize Monologue** (dictionary, modes/instructions, AU/UK spelling), **Voice Notes** (record, processing/recovery, organize/edit/share, auto-tagging), **Web App** (notes on web, edit/organize/share, settings/connections), **Integrations** (choose MCP/CLI/Notes API, connect an AI agent, use the CLI), **Account and Privacy** (billing, permissions/privacy, sign-in/recovery), **Troubleshooting** (dictation/pasting, iPhone/iPad keyboard, performance/crashes, language/unexpected words, connection/diagnostics).
- Tone is terse, task-first, plain-English throughout ("Add the word exactly as you want it written") — no marketing fluff inside docs (that lives on the landing page/blog).
- iOS keyboard setup is spelled out step-by-step: iOS Settings → General → Keyboard → Keyboards → Add New Keyboard → Monologue → enable Full Access, with Apple's standard third-party-keyboard warning surfaced.
- Help Center consolidation: help.every.to's Monologue collection now just says "Monologue Help Center Has Moved," redirecting to monologue.to/docs — suggests a recent docs-platform migration.
- Dedicated per-failure-mode troubleshooting pages (pasting, iOS keyboard, performance/crashes, wrong language, connection/diagnostics) imply these are the recurring real-world support categories.

## Changelog & velocity
- No standalone public changelog/release-notes URL found on monologue.to; release notes live in App Store update text and Every blog posts instead.
- Dated milestones found: Mac dictation launch **Sep 16, 2025**; iOS app with app-based formatting **Feb 18, 2026**; Monologue Notes (bot-free meeting capture + MCP/API/CLI) **Apr 21, 2026**.
- Recent App-Store-note-level shipped items (undated precisely but recent): dictation defaults to **real-time transcription** for faster results; centralized speaker management in Notes (rename speakers, mark yourself, review transcript samples, preview matching audio); safer recording recovery after interrupted calls via a dedicated **Recording Recovery** screen (Settings → Help Center) to export recoverable audio; Monologue keyboard picks up mode changes without restarting; Quick Dictation via Action Button/Shortcuts no longer pauses other audio.
- Usage/scale claims across sources (dates vary): ~7,000 uses/day / 1M+ words/week shortly after Mac launch; later, larger claims of 500M+ words dictated, 100K+ hours saved, 100K+ notes captured, and "processed more than 5 million dictations... more than 250 million spoken words" by the Notes launch — implies fast growth even without a formal changelog page.

## Blog / engineering insights
- Every's Mac launch post (https://every.to/on-every/introducing-monologue-effortless-voice-dictation) is philosophy-first, not technical: *"Monologue doesn't force you into a template or flatten your voice. Instead, it listens, learns, and translates across disciplines and languages."* No latency numbers, model names, or eval methodology disclosed.
- Every's Notes launch post (https://every.to/on-every/introducing-monologue-notes-record-every-meeting-call-and-voice-memo) frames Notes as agent infrastructure rather than a consumer notes app: *"a transit point, an audio capture layer that runs in the background, gathers context, and makes it available"* to coding agents like Claude Code and Codex via MCP/API/CLI.
- No dedicated engineering post on model choice, latency benchmarks, or accuracy evaluation methodology was found in any page crawled — a notable gap in Every's public technical writing (or it simply wasn't surfaced by search).

## User complaints (reviews, Reddit, HN, App Store)
- No Reddit or Hacker News discussion threads were found (Reddit blocked automated/unauthenticated search access; HN Algolia search returned zero relevant stories/comments for "Monologue"/"monologue.to" — likely low community-forum visibility so far given the recent launch, rather than confirmed absence of complaints).
- From third-party review/comparison sites (getvoibe.com, spokenly.app):
  - **Free tier is "the stingiest in the category"**: 1,000 words + 10 notes, one-time (not recurring), ~8 minutes of speech total — creates immediate upgrade pressure for daily users.
  - **Cloud-by-default architecture and DeepContext screen-reading** flagged as a privacy concern — reviewers explicitly say it's "not suitable for NDA-bound or regulated work."
  - **No lifetime purchase option**; subscription cost compounds indefinitely (one review calculates $432 over 3 years at regular annual pricing).
  - **Early-bird $10/mo pricing is explicitly promotional** and may reset to $15/mo — a pricing-trust complaint.
  - **Apple-only** (no Windows/Android) is repeatedly cited as a platform limitation vs. Wispr Flow.
  - **No compliance certifications** (SOC2/HIPAA) — a Wispr Flow advantage called out directly in comparisons.
- Indirect signal from Monologue's own docs: dedicated troubleshooting pages for "Dictation or pasting is not working," "Wrong language or unexpected words," and "Performance and crashes" strongly suggest these are the most common real-world failure categories, even without direct user quotes surfaced.
- Positive counter-signal: Mac App Store cited at **4.9/5 from 172 ratings**, with reviewers calling it "cleaner and less buggy than competitors."

## Best-practice takeaways
1. **Single unambiguous default push-to-talk key** (right Option) plus a fully separate, independently-bound hands-free toggle — never overload one shortcut for two behaviors.
2. **Live mode-switch mid-recording** (right Shift opens a mode picker without stopping dictation) — change tone/format target without restarting the utterance.
3. **Named raw-vs-polished mode** ("Blazing Fast" skips smart post-processing) exposed as a first-class, discoverable setting rather than hidden.
4. **Dictionary import from named competitor apps** (Aqua Voice, Wispr Flow, Superwhisper, Willow Voice) — frictionless-switching onboarding feature.
5. **App/domain-scoped auto-activating modes** — bind a formatting mode to a specific app or website so tone-switching is zero-effort once configured.
6. **Never lose a transcript**: preserve failed/lost pastes in a History log, and show an explicit "Copied" fallback state (with clipboard-fallback setting) rather than silently failing.
7. **Cap language auto-detect scope explicitly** (pick up to 3 expected languages, or declare all languages you'll code-switch between) rather than promising unconstrained free-form multilingual detection — sets accurate expectations and likely improves real accuracy.
8. **Documented, named text-insertion fallback** ("Support non-standard keyboards") for when the default insertion path breaks in a given app.
9. **Outcome-focused custom-instruction authoring guidance** — docs literally teach users how to prompt the formatting layer well, with a concrete example instruction and an iterate-from-one-rule methodology.
10. **Granular indicator verbosity settings** (Classic/Mini/None, always-visible vs. recording-only, per-app hiding) so the recording UI isn't one-size-fits-all.
11. **Meeting auto-detect nudge**: proactively suggest starting a Voice Note when a calling app grabs the mic, with global or per-app dismissal.
12. **Root-cause troubleshooting docs written as decision trees** (e.g., "test with no mode selected to isolate transcription vs. formatting issues") rather than generic FAQ answers.

## Ideas Nasar Flow should steal or beat
1. [steal] **Named raw-vs-polished mode exposed to the user** ("Blazing Fast" equivalent) — even before Nasar Flow has LLM cleanup, exposing a "raw transcript" vs. future "cleaned" toggle as a named mode sets the right mental model early.
2. [steal] **Dictionary/vocabulary import from competitor apps** as an onboarding move — Nasar Flow ships no custom vocabulary yet; when it does, a plain text/CSV import path removes a real switching-cost objection.
3. [beat] **Monologue's default engine sends audio to the cloud for "best accuracy"; on-device is optional and admittedly lower quality.** Nasar Flow's whisper.cpp is offline-only by design — flip this tradeoff and market on-device as strictly better for privacy AND for code-switching-heavy Singlish/Malay/Arabic speech a general cloud model wasn't tuned for. Monologue's own docs concede local accuracy trails cloud — a genuine opening if Nasar Flow's local accuracy on this specific mix is tuned well.
4. [beat] **Monologue's language handling requires manually pre-selecting up to 3 expected languages, and explicitly flags "abrupt language switches" as an accuracy risk** — i.e. its docs concede rapid code-switching (exactly Nasar Flow's core use case) is a weak point. Nasar Flow should make genuinely automatic, no-preselection multilingual code-switch detection a headline differentiator here.
5. [beat] **Text insertion fallback design.** Monologue has a documented, named fallback ("Support non-standard keyboards") plus a "Copied" state + clipboard fallback for when its primary paste/insertion path breaks. Nasar Flow currently relies on manual copy/paste on iOS with no accessibility-API insertion at all — steal the pattern of naming and clearly documenting the fallback flow, and reassure users the transcript is never lost (Nasar Flow should build its own equivalent of Monologue's "History" safety net).
6. [steal] **Visible, size-configurable recording indicator (Classic/Mini/None)** — offer at least always-vs-recording-only indicator states once Nasar Flow has a system-wide capture UI.
7. [beat] **Voice commands: Monologue deliberately has none ("no command syntax required").** This is an open lane — Nasar Flow could own simple hands-free editing commands (e.g. "delete that," "new line") phrased naturally in Singlish/Malay, which Monologue's English-centric, command-free design doesn't address at all for code-switching users.
8. [steal] **Modes scoped to specific apps/domains that auto-activate** — once Nasar Flow has any formatting/tone layer, let users bind a mode to specific apps (e.g., WhatsApp vs. Notes) for automatic switching.
9. [beat] **Zero-data-retention marketing still requires trusting a third-party cloud processor by default, with no SOC2/HIPAA claims at all.** Nasar Flow can make a stronger, simpler privacy claim — "nothing ever leaves the device, full stop" — since it has no cloud path, vs. Monologue's "we promise not to retain what we necessarily see."
10. [steal] **Explicit warning against dictating secrets/passwords/API keys** — worth adding equivalent guidance to Nasar Flow onboarding/docs regardless of on-device-only architecture, since users may assume voice input is inherently as risky as typing near a coworker.
11. [beat] **Free tier structured as a one-time lifetime word cap (1,000 words, ~8 minutes) widely criticized as "stingiest in category."** Nasar Flow, being fully offline with no marginal cloud-compute cost per dictation, should be able to offer unlimited local usage for free as a structural, cost-driven advantage — and should say so explicitly as a differentiator against cloud dictation apps' inherently metered free tiers.
12. [steal] **Meeting-mic-in-use auto-detect nudge** — a lightweight future feature idea: if Nasar Flow ever adds a notes/recording mode, detect when a calling app grabs the mic and prompt the user, mirroring Monologue's meeting-detection reminder.
