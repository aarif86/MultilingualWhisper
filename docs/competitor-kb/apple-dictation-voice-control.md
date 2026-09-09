# Apple Dictation & Voice Control (iOS/iPadOS/macOS)

> Maker: Apple Inc. Not a third-party competitor app — this is the OS-native baseline every user of Nasar Flow already has muscle memory for. Covers Keyboard Dictation, Voice Control, and the new on-device SpeechAnalyzer/SpeechTranscriber API introduced at WWDC25 (iOS/macOS 26).

## Facts
- **Maker / founded / funding:** Apple Inc. First-party OS feature, not a standalone app. Keyboard Dictation dates to iOS 5 (2011, server-side); on-device Dictation since iOS 10/Sequoia-era Macs; Voice Control since iOS/macOS 13 (2019, replacing "Enhanced Dictation"/old Voice Control); SpeechAnalyzer/SpeechTranscriber introduced WWDC25 for iOS/iPadOS/macOS 26.
- **Platforms:** iOS, iPadOS, macOS (Voice Control also on iPhone/iPad/Mac); SpeechAnalyzer API ships on iOS, iPadOS, macOS, visionOS, Mac Catalyst (not watchOS, and has device hardware requirements).
- **Pricing:** Free, built into the OS. No tiers.
- **Engine:** On-device by default for general text Dictation ("your voice inputs and transcripts for general text Dictation ... are processed on your device and not sent to Siri servers") — dictating into a search box is the exception and may be sent to the search provider. No LLM post-processing/cleanup of dictated text by default (raw transcript + rule-based commands only); the new SpeechAnalyzer model is a from-scratch on-device ASR model distinct from the Siri model that powered the older `SFSpeechRecognizer`.
- **Languages:** Dictation is not available in all languages/regions. Per Apple's Feature Availability page, Dictation supports (partial list, by locale): Arabic (Saudi Arabia, UAE), Cantonese (China mainland, Hong Kong), Catalan (Spain), Croatian, Czech, Danish, Dutch (Belgium/Netherlands), **English (Australia, Canada, India, Indonesia, Ireland, Japan, Malaysia, New Zealand, Philippines, Saudi Arabia, Singapore, South Africa, UAE, UK, US)**, Finnish, French (Belgium, Canada, France, Switzerland), German (Austria, Germany, Switzerland), Greek, Hebrew, Hindi, Hungarian, Indonesian, Italian (Italy, Switzerland), Japanese, Korean, **Malay**, Mandarin Chinese (China mainland, Taiwan), Norwegian Bokmål, Polish, Portuguese (Brazil, Portugal), Romanian, Russian, Shanghainese, Slovak, Spanish (Chile, Colombia, Mexico, Spain, US), Swedish, Thai, Turkish, Ukrainian, Vietnamese. **English (Singapore) is a supported Dictation locale.** No "Arabic (Singapore)" variant exists — Singapore Arabic-script code-switching users would fall back to a generic Arabic locale. Code-switching/auto-detect: none in classic Dictation — it is single-locale per session, selected in advance (you can set up Dictation for multiple languages and switch mid-document via the Globe key on Mac, or via keyboard switch on iOS, but each utterance is transcribed in one fixed language). Bilingual Siri (iOS 17) added mixed-language *voice command* understanding for English + one of Hindi/Telugu/Punjabi/Kannada/Marathi — this is a Siri-request feature, not general Dictation. iOS 18 added a single keyboard containing two typing languages, but this multilingual keyboard explicitly **does not extend to Dictation** — dictation still runs against one fixed locale even when a bilingual keyboard is active, and community reports (Apple Discussions) describe dictation reverting to the keyboard's first language and failing to switch, with the workaround being to delete the bilingual keyboard and use separate monolingual keyboards.
- **Docs / KB / blog / changelog URLs (all crawled):**
  - https://support.apple.com/guide/iphone/dictate-text-iph2c0651d2/ios
  - https://support.apple.com/guide/iphone/commands-for-dictating-text-iph3bf19d7b9/ios
  - https://support.apple.com/guide/iphone/use-voice-control-iph2c21a3c88/ios
  - https://support.apple.com/guide/mac-help/use-dictation-mh40584/15.0/mac/15.0
  - https://support.apple.com/guide/mac-help/commands-for-dictating-text-on-mac-mh40695/15.0/mac/15.0
  - https://support.apple.com/guide/mac-help/use-voice-control-commands-mh40719/15.0/mac/15.0
  - https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html
  - https://developer.apple.com/documentation/uikit/configuring-a-custom-keyboard-interface
  - https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
  - https://developer.apple.com/videos/play/wwdc2025/277/ (WWDC25 session 277, "Bring advanced speech-to-text to your app with SpeechAnalyzer" — transcript crawled)
  - https://developer.apple.com/documentation/speech/sfspeechrecognizer
  - https://developer.apple.com/documentation/speech/speechanalyzer
  - https://developer.apple.com/documentation/speech/speechtranscriber
  - https://developer.apple.com/documentation/Speech/bringing-advanced-speech-to-text-capabilities-to-your-app
  - https://developer.apple.com/forums/thread/775077 (keyboard-extension microphone error report)
  - https://www.apple.com/siri/
  - https://www.apple.com/ios/feature-availability/
  - https://support.apple.com/en-sg/121115 ("How to get Apple Intelligence" — Singapore-region page)
  - https://techcrunch.com/2023/07/12/apple-introduces-bilingual-siri-and-a-full-page-screenshot-feature-with-ios-17 (bilingual Siri, iOS 17 announcement coverage)
  - https://www.macstories.net/stories/ios-and-ipados-18-the-macstories-review/12/ (iOS 18 bilingual keyboard vs. dictation review)

## Activation & capture UX
- **iPhone/iPad:** Enable once in Settings > General > Keyboard > Enable Dictation. Then, anywhere there's a text field: tap the field to place the cursor, tap to bring up the onscreen keyboard, tap the microphone key next to the insertion point, and speak — dictation begins when the mic glyph appears near the insertion point. Stop by tapping the mic again or saying "Stop dictation." **Dictation auto-stops after 30 seconds of silence.** No push-to-talk vs. toggle choice is exposed — it's a single tap-to-start/tap-to-stop toggle. Typing and Dictation can be freely interleaved; the keyboard stays open during Dictation.
- **Mac:** Press the Microphone function key if present (press-and-release starts Dictation; press-and-hold instead activates Siri on the same key), or a user-customizable keyboard shortcut (default is often double-press Fn, or a chosen combo like Option-Z), or menu Edit > Start Dictation. A tone plays and a mic glyph appears above/below the insertion point when ready. On Apple silicon Macs you can keep typing while dictating — the mic glyph hides while you type and reappears when you pause. **No 30-second cap on Mac** — "You can dictate text of any length without a timeout" — but it still auto-stops after 30 seconds of silence. Stop via Escape key, the Microphone key, or the shortcut again.
- **Feedback while recording:** A microphone icon near the cursor (glyph state = actively listening); an audible tone confirms Dictation is ready; on Mac, ambiguous transcription results are underlined in blue and clickable for alternatives. No visible waveform/level meter is described in Apple's own docs (unlike many competitor apps) — feedback is limited to the mic glyph + tone + live partial text appearing in the field as you speak.
- **On release/stop:** Whatever was transcribed (finalized text) remains in the field; there's no separate "confirm" step — text lands live as you dictate.
- **Voice Control (a distinct, heavier accessibility mode, not just dictation):** Settings > Accessibility > Voice Control > Set Up Voice Control triggers a one-time online file download, after which it works fully offline. Once on, a status-bar glyph shows Voice Control is active. Turn on/off via Control Center toggle, Accessibility Shortcut (triple-click side/home button), or asking Siri "Turn on Voice Control." **Important: when Voice Control is on, it replaces standard OS Dictation entirely** — "you use Voice Control to dictate text; standard iOS/macOS Dictation isn't available."

## Text insertion
- Dictation inserts text directly at the current insertion point of whatever native text field/app currently has keyboard focus — it is a first-party, system-level input path (not accessibility-API injection or paste-simulation), because Dictation is invoked through the system keyboard itself, not through an app extension.
- On Mac, ambiguous words are underlined in blue in place and can be corrected in-line by click or by re-dictating/typing over them.
- Custom (third-party) keyboards on iOS **cannot replicate this** — see Privacy & data / architecture note below: third-party keyboard extensions have zero microphone access, so they cannot offer an equivalent in-keyboard mic button; Apple's own dictation mic key is a privilege reserved for the system keyboard.

## Accuracy & personalization
- Dictation itself exposes no visible custom-vocabulary/spelling-list UI in the consumer docs beyond the in-line spelling command ("Let's invite Steven S-T-E-P-H-E-N" / "Change tea to T-E-E"), which lets a user dictate an unusual name letter-by-letter to force correct spelling in the moment — this is the primary "teach it a word" mechanism for plain Dictation.
- Voice Control has a dedicated **Vocabulary** setting: users can teach it new words/phrases and how they're pronounced, or import a vocabulary list wholesale — but Apple notes "not all Voice Control languages support a custom vocabulary."
- Auto-punctuation (see below) is itself a personalization/accuracy layer — supported-language dictation infers commas, periods, and question marks from prosody without the user speaking punctuation names.
- SpeechTranscriber (the new WWDC25 API) exposes `SpeechTranscriber.supportedLocales` / `installedLocales` / `supportedLocale(equivalentTo:)` for apps to check language support and manage on-device model assets themselves — but this is a developer API, not an end-user personalization feature.

## Formatting & AI cleanup
- No filler-word removal, no LLM-based rewriting/cleanup, no tone/style modes are exposed in stock Dictation — it is a literal transcript plus explicit spoken formatting commands (see command list below). This is a meaningfully "rawer" experience than most modern third-party dictation apps.
- **Auto-punctuation**: "In supported languages, Dictation automatically inserts commas, periods, and question marks as you dictate." Toggle at Settings > General > Keyboard > Auto-Punctuation (iOS) / System Settings > Keyboard > Dictation > Auto-punctuation (Mac). This is the single most copied convention across the dictation-app market — see Best-practice takeaways.
- Formatting is otherwise 100% voice-command driven: "new line," "new paragraph," "cap," "caps on/off," "all caps," "all caps on/off," "no space on/off," "numeral," "roman numeral," "tab key" (Mac only in the crawled command list). See full verbatim list below.
- No "raw vs. polished" toggle, no per-app context awareness, no prompt/instruction mode — this is the clearest gap vs. AI-native dictation competitors.

## Voice commands
Apple ships two separate, non-overlapping systems:
1. **Dictation commands** — a fixed, small, always-available command set active only while the mic is actively transcribing (punctuation names, formatting words, "select/delete X," "undo/redo," emoji names, and on US English iPhone 12+, structured edit commands like "Change X to Y," "Insert X before/after Y").
2. **Voice Control** — a full alternate input modality that replaces Dictation when active, with hundreds of screen-control commands (navigation, tap-by-name/number, grid overlay, scrolling, app switching) plus its own text-entry sub-modes (Dictation mode / Spelling mode / Command mode). Voice Control's full command reference is not published as static text by Apple — it's browsable only on-device at Settings > Accessibility > Voice Control > Commands — so the phrases below are the ones Apple's own docs quote as examples, not an exhaustive dump.

See the dedicated "Full command list" section below for verbatim phrases with citations.

## Languages & multilingual
- **Auto language detection:** none. Dictation locale is fixed per session to whichever keyboard/dictation language is currently selected; there is no automatic detection of what language the user is speaking.
- **Mixed-language in one utterance (the feature Nasar Flow competes hardest on):**
  - **Bilingual Siri (iOS 17, 2023):** Siri (voice *commands*, not general Dictation) gained the ability to understand a single utterance mixing English with one of five Indic languages — Hindi, Telugu, Punjabi, Kannada, or Marathi — targeted explicitly at Indian users who code-switch in daily speech. This does not extend to general-purpose text Dictation and does not include Malay, Arabic, or Singlish pairs.
  - **iOS 18 bilingual keyboard (2024):** introduced one software keyboard containing two typing languages so users can type mid-sentence code-switched text without swapping keyboards. Apple's own docs and MacStories' review are explicit that **this multilingual-keyboard feature does not extend to Dictation** — dictation still transcribes against one fixed locale. Community reports on Apple Discussions describe dictation getting stuck on the keyboard's first configured language and failing to pick up the second language via voice, with the practical workaround being to delete the bilingual keyboard and dictate using separate single-language keyboards instead.
  - No Apple document found (through iOS/macOS 26) claims general-purpose Dictation can transcribe a single utterance that freely mixes two arbitrary languages (e.g., English+Malay or English+Arabic) the way Nasar Flow is designed to. This is Apple's clearest, most defensible gap for Nasar Flow's Singlish/Malay/Arabic code-switching pitch.
- **Translation:** not a Dictation feature at all (separate Translate app/feature).
- **Per-language quirks:** auto-punctuation, custom vocabulary, and Spelling mode are all explicitly called out as "not available in all languages." Emoji-by-voice ("heart emoji") is also language-gated — Apple points to the Feature Availability page rather than listing which languages support it.
- **Singapore English (en-SG):** confirmed as a supported on-device Dictation locale per Apple's Feature Availability page (listed explicitly as "English (Singapore)"). Malay is listed as a supported Dictation language (generic, not Singapore-specific). No Singapore-specific Arabic variant exists in the list.

## Privacy & data
- General text Dictation: "your voice inputs and transcripts for general text Dictation (for example, composing messages and notes, but not dictating in a search box) are processed on your device and not sent to Siri servers." Dictating into a search box is the carved-out exception — that audio may be sent to the search provider.
- Users are asked (opt-in) whether to "Share Audio Recordings" with Apple to help improve Siri & Dictation; this can be toggled later in Privacy & Security > Analytics & Improvements > Improve Siri & Dictation, and shared audio history can be deleted at any time ("associated with a random identifier and less than six months old").
- Voice Control requires a one-time online file download per language, then runs fully offline.
- SpeechAnalyzer/SpeechTranscriber (WWDC25 API): explicitly on-device — "The new API leverages the power of Swift to perform speech-to-text processing and manage model assets on the user's device with very little code." Model assets are managed by the OS via `AssetInventory`, stored in system storage (don't count against the app's own storage/memory budget), and run in a separate process outside the app's own memory space.
- No SOC2/HIPAA/enterprise-specific Dictation controls are documented (this is a consumer OS feature, not an enterprise product).

## Onboarding & docs
- Onboarding is a single Settings toggle for Dictation (Enable Dictation) with an inline "About Dictation & Privacy" link and an OS-level Share/Don't Share Audio Recordings prompt on first real use.
- Voice Control has a proper interactive on-device tutorial (Settings > Accessibility > Voice Control > Open Voice Control Tutorial) that walks through essential commands — a more structured first-run experience than Dictation gets.
- Apple's documentation is split cleanly by topic (Dictate text / Commands for dictating text / Use Voice Control commands), lives inside the versioned iPhone/Mac User Guide (support.apple.com/guide/...), and is written in Apple's standard terse task-based house style: short numbered steps, "Note:" callouts for caveats, "See also" cross-links at the end of every article. No dedicated Dictation troubleshooting or status page beyond the generic "If Dictation on Mac doesn't work as expected" article and the iOS/macOS Feature Availability matrix page.

## Changelog & velocity
- iOS 10 (2016): `SFSpeechRecognizer` introduced — first public on-device-capable speech API, backed by the Siri model.
- iOS/macOS 13 (2019): modern Voice Control introduced (grid/numbers overlay, Spelling/Command modes).
- iOS 17 (2023): Bilingual Siri (English + one of five Indic languages).
- iOS 18 (2024): single keyboard supporting two typing languages (explicitly not extended to Dictation).
- iOS/iPadOS/macOS 26 + WWDC25 (2025): SpeechAnalyzer + SpeechTranscriber + DictationTranscriber APIs — new from-scratch on-device ASR model, faster and better on long-form/distant audio than the SFSpeechRecognizer-era model, now powering Notes/Voice Memos/Journal call-and-audio transcription and exposed to third-party developers.

## Blog / engineering insights
- WWDC25 session 277, "Bring advanced speech-to-text to your app with SpeechAnalyzer" (https://developer.apple.com/videos/play/wwdc2025/277/) is the single richest engineering source found. Key claims, quoted from the crawled transcript:
  - On why the old API fell short: "[SFSpeechRecognizer] worked well for short-form dictation and it could use Apple servers on resource-constrained devices but it didn't address some use cases as well as we, or you, would have liked and relied on the user to add languages."
  - On the new model: "The new model is both faster and more flexible than the one previously available through SFSpeechRecognizer. It's good for long-form and distant audio, such as lectures, meetings, and conversations."
  - Architecture: a `SpeechAnalyzer` session holds one or more modules (e.g. `SpeechTranscriber`); audio flows in via an `AsyncStream`/`AnalyzerInput` sequence; results stream out asynchronously and are correlated to audio via precise per-sample timecodes, decoupling input from output entirely.
  - **Volatile vs. finalized results** — Apple's own term for interim/partial transcription: "immediate rough results" delivered almost as soon as they're spoken (opt-in via `.volatileResults`), superseded later by one finalized result per audio range; this is the direct analog to "interim results" in Nasar Flow's UX and is worth matching terminology-wise.
  - Model assets are downloaded/managed on-device via `AssetInventory`, live in system storage outside the app's own memory/storage budget, and are auto-updated by the OS.
  - `DictationTranscriber` is offered as a fallback class for locales/devices `SpeechTranscriber` doesn't support, and explicitly improves on the old flow: "you will NOT need to tell your users to go into Settings and turn on Siri or keyboard dictation for any particular language."
  - Apple's own worked example app is a "kids' bedtime story" recorder with live transcription and word-level playback highlighting driven by `audioTimeRange` metadata on the `AttributedString` result — a useful reference pattern for word-level highlight/karaoke-style playback UI.

## User complaints (reviews, Reddit, HN, App Store)
- Apple Discussions threads (crawled via search, e.g. "iOS 18.5: Cannot switch dictation language," "iOS 18 Update: English and Swedish Keyboard...") repeatedly report that once a bilingual/multilingual keyboard is configured, Dictation gets stuck transcribing in the keyboard's first configured language and won't follow a manual language switch — the documented workaround is to delete the bilingual keyboard entries and reconfigure as separate single-language keyboards.
- A live, unresolved Apple Developer Forums thread (https://developer.apple.com/forums/thread/775077) documents a distinct `!rec`/error 561145187 failure when a *developer's* keyboard extension attempts to record audio even with Full Access and microphone permission granted and `RequestsOpenAccess` set — Apple's own engineer response points only to the standard `hasDictationKey`/open-access configuration docs, with no resolution as of the thread's most recent activity, reinforcing that microphone access from a keyboard extension is a hard platform wall, not a permissions-configuration problem.

## Best-practice takeaways
1. **Auto-punctuation as a silent default** — Apple infers commas/periods/question marks from speech prosody in supported languages, with an explicit off-switch named exactly "Auto-Punctuation" (iOS) / "Auto-punctuation" (Mac). Nasar Flow should keep matching this default-on, opt-out framing and naming.
2. **A tiny, memorized, always-available command vocabulary** rather than a sprawling one: "new line," "new paragraph," "cap"/"caps on/off," "all caps"/"all caps on/off," "no space on/off," plus punctuation-by-name and emoji-by-name. Keep Nasar Flow's core command set this small and this consistent across sessions.
3. **Letter-by-letter spelling escape hatch** — "Let's invite Steven S-T-E-P-H-E-N" / "Change tea to T-E-E" — gives users a deterministic way to force a spelling without needing a custom-vocabulary settings screen. Cheap to copy, high value for names/brand terms in Singlish contexts.
4. **"Volatile" vs. "finalized" as the vocabulary for interim results** — Apple's own chosen terms, with volatile results shown in a lighter/different visual treatment before being replaced by finalized text. Adopt equivalent visual language (e.g., dim/italic partial text -> solid final text) for consistency with what iOS power-users already expect.
5. **No timeout ambiguity, but a firm one:** dictation always auto-stops after **30 seconds of silence** on both iPhone and Mac (iPhone additionally caps overall length at 30s per session in some framings, Mac has no hard length cap). Communicate Nasar Flow's own silence-timeout value explicitly and make it feel at least as generous.
6. **Ambiguous-word inline correction UI** (Mac): underline the uncertain word in blue, let a click or re-dictation fix it in place, rather than hiding uncertainty. A concrete, low-cost, high-trust affordance Nasar Flow could adopt for code-switched words the model is unsure about.
7. **Dictation-support signaling for keyboards is a first-class API concern** (`hasDictationKey` on `UIInputViewController`): if Nasar Flow ever ships a real custom keyboard, it must explicitly declare whether it offers dictation-like input so iOS doesn't also draw its own (nonfunctional, since mic access is blocked) system dictation button on top of it.
8. **Bilingual support has shipped narrowly, by named language pair, not generally** — Apple's own bilingual Siri only covers English + one of five specific Indic languages, and iOS 18's bilingual *keyboard* explicitly does not extend to *dictation* at all. This is the biggest open door for Nasar Flow's Singlish/Malay/Arabic-in-one-utterance pitch — genuinely no current Apple feature does this end-to-end.

## Ideas Nasar Flow should steal or beat
1. [steal] Copy Apple's exact **auto-punctuation on-by-default, one-toggle-off** UX and naming convention — users already expect a setting literally called "Auto-Punctuation."
2. [steal] Copy the **small, fixed, cross-session-stable command vocabulary** shape (a dozen-ish words: new line, new paragraph, cap, caps on/off, all caps, no space on/off, undo/redo, select/delete X) rather than growing a large bespoke command surface — matches existing muscle memory from Apple Dictation.
3. [steal] Copy the **spell-it-out escape hatch** ("Change X to Y-Y-Y") as a lightweight, no-settings-screen way to fix names/uncommon words mid-dictation.
4. [steal] Copy **"volatile" -> "finalized"** as the internal/UX vocabulary and visual treatment for interim vs. final transcription, since it's now Apple's own platform-level term as of WWDC25/iOS 26 and third-party apps that echo it will feel native.
5. [beat] Apple's bilingual support is narrow and pair-specific (English+Hindi/Telugu/Punjabi/Kannada/Marathi for Siri commands only) and explicitly does **not** cover Dictation or Singlish/Malay/Arabic. Nasar Flow's actual single-utterance Singlish/Malay/Arabic code-switching dictation is a capability Apple does not ship anywhere in its stack today — this is the single most defensible, most marketable gap and should be the headline claim ("dictation that actually understands how Singaporeans talk" vs. Apple's fixed-locale-per-session model).
6. [beat] Apple Dictation shows almost no recording feedback beyond a static mic glyph and a tone — no waveform, no level meter. Nasar Flow's richer waveform/level visualization is already a concrete UX upgrade over the platform default and worth calling out explicitly in comparison marketing.
7. [beat] Apple's bilingual keyboard (iOS 18) is documented and reported by users to actively break Dictation language-switching. Nasar Flow should make "switching languages never breaks dictation" a tested, explicit guarantee and potential comparison talking point.
8. [beat] Third-party keyboards are structurally barred from microphone access on iOS ("No access to microphone and speaker" — confirmed both in Apple's 2014-era Custom Keyboard programming guide and its current `configuring-open-access-for-a-custom-keyboard` doc). Nasar Flow's keyboard extension is bound by the same platform wall and cannot record audio itself from inside the extension — the practical workaround (companion app / Action Extension / Shortcuts hand-off to record, then return text to the keyboard/host app) should be treated as a hard architecture constraint to design around, not a bug to chase; document this clearly for engineering so no one wastes time trying to get raw mic frames inside the keyboard extension process itself.

## Full command list

### Dictation commands (iPhone)
Source: https://support.apple.com/guide/iphone/commands-for-dictating-text-iph3bf19d7b9/ios

**Punctuation** (Command → Result): Period → `.` · Comma → `,` · Exclamation point → `!` · Question mark → `?` · Dollar sign → `$` · Open parenthesis → `(` · Close parenthesis → `)` · Quote → `"` · End quote → `"` · Colon → `:` · Semicolon → `;` · Hashtag → `#`
*("For some languages, Dictation automatically adds certain punctuation as you dictate text.")*

**Format text:**
- "Cap" → Capitalize the next word
- "Caps on" … "caps off" → Capitalize the first character of each enclosed word
- "All caps" → Make the next word all uppercase
- "All caps on" … "all caps off" → Make the enclosed words all uppercase
- "No caps on" … "no caps off" → Make the enclosed words all lowercase
- "No space" → Eliminate the space between two words (not available for all languages)
- "No space on" … "no space off" → Run a series of words together (not available for all languages)
- "New paragraph" → Start a new paragraph
- "New line" → Start a new line

**Change, insert, and delete text** (U.S. English on iPhone 12 and later, except iPhone SE):
- "Change [x] to [y]" → Replace existing text with new text
- "Insert [x] before [y]" → Insert new text before existing text
- "Insert [x] after [y]" → Insert new text after existing text
- "Select [x]" → Select text
- "Delete [x]" → Delete text
- "Delete all" → Delete all text
- "Undo" → Undo the action
- "Redo" → Redo the action

**Insert emoji:** say the emoji's name, e.g. "heart emoji," "car emoji," "smiley emoji," "halo emoji," "laugh out loud emoji," "heart eyes emoji," "amazing emoji," "yum emoji," "congrats emoji," "goofy emoji," "sick emoji," "scream emoji," "hug emoji," "fingers crossed emoji," "purple heart emoji," "cheers emoji," "celebrate emoji," "speech balloon emoji," "puppy emoji," "music emoji," "rainbow emoji," "present emoji." (Emoji-by-voice availability is language-gated per Apple's Feature Availability page.)

Also, from the companion "Dictate text on iPhone" page (https://support.apple.com/guide/iphone/dictate-text-iph2c0651d2/ios):
- "Let's invite Steven S-T-E-P-H-E-N" / "Change tea to T-E-E" → spell a word letter-by-letter
- "Undo" / "Redo" → undo or repeat a command
- Tap the field, or say "Stop dictation" → stop dictating (auto-stops after 30 seconds of silence)

### Dictation commands (Mac)
Source: https://support.apple.com/guide/mac-help/commands-for-dictating-text-on-mac-mh40695/15.0/mac/15.0

**Punctuation:** apostrophe → `'` · open bracket → `[` · close bracket → `]` · open parenthesis → `(` · close parenthesis → `)` · open brace → `{` · close brace → `}` · open angle bracket → `<` · close angle bracket → `>` · colon → `:` · comma → `,` · dash → `–` · ellipsis → `…` · exclamation mark → `!` · hyphen → `-` · period/point/dot/full stop → `.` · question mark → `?` · quote → `"` · end quote → `"` · begin single quote → `'` · end single quote → `'` · semicolon → `;`

**Typography:** ampersand → `&` · asterisk → `*` · at sign → `@` · backslash → `\` · forward slash → `/` · caret → `^` · center dot → `・` · large center dot → `●` · degree sign → `°` · hashtag/pound sign → `#` · percent sign → `%` · underscore → `_` · vertical bar → `|`

**Formatting:** "new line" → starts a new line · "numeral" → formats the next phrase as a number · "roman numeral" → formats the next phrase as a Roman numeral · "new paragraph" → starts a new paragraph · "no space on" → formats the next phrase without spaces · "no space off" → resumes default spacing · "tab key" → moves the cursor to the next tab stop

**Capitalization:** "caps on" → formats the next phrase in Title Case · "caps off" → resumes default case · "all caps" → formats the next word in ALL CAPS · "all caps on" → formats the next phrase in ALL CAPS · "all caps off" → resumes default case

**Mathematical:** equal sign → `=` · greater than sign → `>` · less than sign → `<` · minus sign → `-` · multiplication sign → `x` · plus sign → `+`

**Currency:** dollar sign → `$` · cent sign → `¢` · pound sterling sign → `£` · euro sign → `€` · yen sign → `¥`

**Emoticons:** smiley face → `:-)` · frowny face → `:-(` · winky face → `;-)` · cross-eyed laughing face → `XD`

**Intellectual property:** copyright sign → `©` · registered sign → `®` · trademark sign → `™`

### Voice Control commands (iPhone)
Source: https://support.apple.com/guide/iphone/use-voice-control-iph2c21a3c88/ios

- General: "Open Control Center," "Go home," "Tap [item name]," "Turn up volume."
- Listening control: "Stop listening" / "Start listening" (pause/resume without triggering commands or dictation).
- Discoverability: "Show commands" (lists commands available in the current app/context).
- Labeling on-screen items: "Show names," "Show numbers," or "Show text numbers" → labels items so you can say the item's name/number, or a command like "Long press [item name/number]."
- Grid overlay: "Show grid" → superimposes a numbered grid; say a command (e.g. "Tap [grid number]") to act on that cell, or say a number alone to drill into a more detailed sub-grid there. "Hide names," "Hide numbers," or "Hide grid" → turns any overlay off.
- Text entry modes:
  - "Dictation mode" (default) — dictate word by word; non-command words are entered as text.
  - "Spelling mode" — dictate character by character; use phonetic alphabet words for accuracy (e.g. "Alfa Bravo Charlie" → "abc"); not available in all Voice Control languages.
  - "Command mode" — Voice Control responds only to commands; nothing is entered as text.
- Text editing examples once numbers are shown next to words/characters: "Delete [item number]," "Uppercase [item number]."
- Full reference: Apple does not publish the complete command list as static text — it directs users to browse it live on-device at Settings > Accessibility > Voice Control > Commands, and to the in-app "Voice Control Tutorial" (same path) for interactive practice.

### Voice Control commands (Mac)
Source: https://support.apple.com/guide/mac-help/use-voice-control-commands-mh40719/15.0/mac/15.0

- General: "Open Mail," "Scroll down," "Click Done." (Pause ~0.5s between rapid-fire commands, e.g. "Scroll up," "Move cursor right 5 pixels," "Press OK.")
- Listening control: "Stop listening" / "Start listening."
- Discoverability: "Show commands"; full browsable list via Apple menu > System Settings > Accessibility > Voice Control > Commands.
- Labeling: "Show names" or "Show numbers"; "Show text numbers" / "Hide text numbers" for number overlays specifically in text areas. Interact via "[command] [name/number]," e.g. "Click [item]." "Hide names" / "Hide numbers" to clear.
- Grid overlay: "Show grid" (whole screen) or "Show window grid" (active window only); drill down by saying a grid number repeatedly; "Hide grid" to clear.
- Drag and drop with overlays active: "Drag [item name or number] to [location name or number]."
- Text entry modes (shared between Dictation mode and Spelling mode for text-editing commands): "Dictation mode," "Spelling mode," "Command mode" — same behavior/definitions as iPhone above. Example cross-mode command: "Replace cat with dog" (Dictation mode) vs. "Replace Charlie Alfa Tango with Delta Oscar Golf" (Spelling mode).
- Text editing once numbered: "Delete [number]," "Uppercase [number]."
- VoiceOver integration: "VoiceOver rotor," "VoiceOver read all," "VoiceOver select first item" (full list via Accessibility > Voice Control > Commands > Accessibility commands section).
