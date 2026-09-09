# Google Gboard / Assistant voice typing / Android on-device speech / ChromeOS Dictation (+ Samsung Keyboard, brief)

> Google's OS-native and keyboard-native voice input stack: Gboard voice typing (Android/iOS), the newer Gemini-powered "Rambler" / advanced voice typing on Pixel, the Android `SpeechRecognizer`/`RecognitionService` system API, and ChromeOS Dictation — plus a brief look at Samsung Keyboard's voice input. For anyone with a phone, this is the default free "competitor" Nasar Flow has to feel obviously better than.

## Facts
- **Maker / founded / funding:** Google (Gboard team; Android platform team for `SpeechRecognizer`/`RecognitionService`; ChromeOS team). Samsung (Samsung Keyboard, part of One UI). Not funded startups — bundled OS/first-party-app features.
- **Platforms:** Gboard — Android and iOS. Advanced/"Rambler" voice typing — Android only, gated to specific Pixel models (Pixel 6+ for basic advanced features, Pixel 8+ for detailed edits, Pixel 9+ excluding 9a for writing-tools voice commands, **Pixel 11** for Rambler). `SpeechRecognizer`/`RecognitionService` — Android system API (on-device path added Android 13 / API 33+). Dictation — ChromeOS. Samsung Keyboard — Samsung Android devices (One UI).
- **Pricing:** Free, bundled with the OS/keyboard app. No paid tier.
- **Engine:** Mixed. Base Gboard voice typing has historically been cloud-backed speech-to-text; Android 13+ added a system-level **on-device** `RecognitionService` path apps can request via `SpeechRecognizer.createOnDeviceSpeechRecognizer()` / `checkRecognitionSupport()`. Pixel's "advanced voice typing" layers on top of the base recognizer with on-device post-processing ("Writing tools proofreading happens on-device, ensuring data privacy" per Google's own docs). **Rambler** (new, Gboard help article `answer/17468539`) is explicitly **Gemini-powered**: it rewrites raw speech into clean text, has an offline fallback mode with reduced features, and states audio/text are only "temporarily processed" and never stored. ChromeOS Dictation's underlying engine (on-device vs cloud) is not documented on its support page. Samsung Keyboard voice input piggybacks on the Google/Android speech recognition stack on most Samsung devices rather than shipping a distinct proprietary engine (see caveat in the Samsung section — I could not locate a dedicated Samsung support article confirming implementation details within this research pass).
- **Languages:** Base Gboard voice typing: broad list, but "Talk-to-text doesn't work with all languages" and "Punctuation might not be available in all languages" (exact list not published on the help page fetched). Pixel advanced voice typing's automatic multi-language detection: English, French, German, Italian, Japanese, Spanish. Rambler: 11 languages — Arabic, English, French, German, Hindi, Italian, Japanese, Korean, Portuguese, Russian, Spanish — with **mid-sentence language switching** supported. ChromeOS Dictation's newer editing commands: "You can only use these new commands in English, French, German, Italian, and Spanish"; base dictation requires the spoken language to match the device's set language.
- **Docs / KB / blog / changelog URLs (all crawled):**
  1. https://support.google.com/gboard (help center hub)
  2. https://support.google.com/gboard/answer/2781851?hl=en — "Type with your voice" (base Gboard voice typing)
  3. https://support.google.com/gboard/answer/11197787?hl=en — "Use advanced voice typing features" (Pixel-specific, on-device post-processing)
  4. https://support.google.com/gboard/answer/17468539?hl=en — "Rambler voice input on Gboard" (Gemini-powered, Pixel 11)
  5. https://support.google.com/gboard/topic/9024098?hl=en — "Use more Gboard features" topic hub (lists all the above plus related articles)
  6. https://support.google.com/chromebook (help center hub)
  7. https://support.google.com/chromebook/answer/12001244?hl=en — "Type text with your voice" (ChromeOS Dictation)
  8. https://support.google.com/pixelphone (help center hub — checked for a distinct "Assistant voice typing" article; see note below)
  9. https://support.google.com/assistant/?hl=en-GB (Google Assistant help hub — checked; no dedicated voice-typing article found there)
  10. https://developer.android.com/reference/android/speech/SpeechRecognizer — Android `SpeechRecognizer` API reference (on-device recognition methods)
  11. https://developer.android.com/reference/android/speech/RecognitionService — Android `RecognitionService` API reference
  12. https://developer.android.com/about/versions/13/features — Android 13 feature overview (checked for a speech-recognition callout; not listed as a headline feature there, despite the API landing in API 33)
  13. https://www.samsung.com/sg/support/mobile-devices/ — Samsung Singapore mobile support hub (checked for a keyboard voice-input article; none found in the crawlable listing)
  14. https://web.archive.org/ (Wayback Machine CDX API, `web.archive.org/cdx/search/cdx`) — used to confirm `support.google.com/gboard/answer/11197787` is the long-standing canonical "voice typing" article (internally tagged `p=voice_typing` in tracked outbound links since at least 2021-11-03) and that no separate "Assistant voice typing"-titled article exists under `support.google.com/pixelphone` or `support.google.com/gboard`.

  **Research note on "Assistant voice typing":** the brief asked specifically for a distinctly-branded "Assistant voice typing" Pixel article. After searching Google's Gboard, Pixel Phone, and Assistant help hubs (URLs 1, 8, 9 above) and multiple search-engine passes, I could not find a support.google.com article carrying that exact title. What Google's own docs *do* have, and what functionally matches the brief's description ("newer on-device Pixel-specific voice typing distinct from Gboard's older voice typing"), is **"Use advanced voice typing features"** (URL 3) — gated to Pixel 6+ hardware, with on-device proofreading — and the newer **Rambler** (URL 4) on Pixel 11. This doc treats those two as the "Assistant voice typing"-equivalent tier and cites them explicitly wherever that distinction matters.

## Activation & capture UX
- **Base Gboard voice typing:** open any text field → tap the microphone key at the top of the keyboard → wait for the "Speak now" prompt → speak. Toggle-style (not push-to-talk): tapping again or tapping "Done" stops it. Available on both Android and iOS Gboard.
- **Advanced/Pixel voice typing:** same entry point (mic key), but once started the system recognizes it's a supported Pixel and offers the richer command set. Users can keep typing manually while the mic stays active — dictation and typing are not mutually exclusive.
- **Rambler:** first use shows an intro dialog with a "Start" button; after that it launches from the same mic key, or can be explicitly selected as the active voice-typing engine via Settings → Voice typing. Needs an internet connection for full quality; explicitly has a reduced-feature offline mode (a "Retry" button appears to reprocess once connectivity returns).
- **ChromeOS Dictation:** enabled once, in Settings → Accessibility → "Keyboard and text input" → Dictation toggle. Activated per-use either by clicking the Dictation microphone icon or the keyboard shortcut **Search+D** / **Launcher+D** (also reachable via **Alt+Shift+S** to get to the relevant settings shortcut per the fetched page). Click into a text field first, then trigger Speak.
- **UI feedback while recording:**
  - Gboard: primarily textual — "Speak now" appears on the keyboard row; no waveform/color detail was documented on the fetched help pages (Google's own text is thin here).
  - Rambler: described as showing **"a glowing animation"** to indicate active listening, plus icon buttons for microphone / Done / Menu / Settings.
  - ChromeOS Dictation: displays **"a box"** showing the live transcribed text while you speak, which clears before the system accepts a voice command.
- **Interim/partial results:** not explicitly documented for Gboard on the pages crawled; ChromeOS shows the live text box and Rambler's cloud path implies live streaming transcription with a final "clean-up" pass after you stop. Nothing found describing haptic feedback for any of these.

## Text insertion
Gboard voice typing inserts text the same way normal typing does — through the standard Android/iOS input-method-editor commit path (i.e., it behaves as if the words were typed), so it works in essentially any text field the keyboard can reach. Rambler's "editing" commands ("change X to Y", "insert X before Y") operate on the text already committed in the field, implying it keeps its own working buffer/model of the current text rather than only appending. ChromeOS Dictation similarly types into whatever field has focus. No published fallback behavior or "known-broken apps" list was found in the crawled docs.

## Accuracy & personalization
- Rambler explicitly "transforms natural, spoken thought into clean, well-structured written text" rather than doing literal transcription — filler-word removal and grammar/punctuation formatting happen automatically, and users can steer style live ("Make this sound more professional," "Make this shorter and more direct").
- Pixel advanced voice typing's "Writing tools" commands include proofread/rephrase/formalize/casual/lengthen/shorten — a form of on-the-fly personalization of tone rather than vocabulary.
- No custom dictionary, contact-name injection, or per-app context features were documented on any of the crawled pages for Gboard/Assistant/Rambler/ChromeOS voice typing (this is a real gap versus dedicated dictation apps).
- Nothing found on auto-learning from corrections for the voice-typing path specifically (Gboard's typing autocorrect learns from taps, but the docs don't claim the voice path learns similarly).

## Formatting & AI cleanup
- Base Gboard voice typing: automatic punctuation insertion "as you speak" per the advanced-features page; punctuation coverage varies by language.
- Pixel advanced voice typing: auto-punctuation plus the Writing Tools rewrite commands (proofread, rephrase, formalize, casualize, lengthen, shorten) — these are essentially prompt-style commands spoken mid-dictation.
- Rambler: the whole feature is built around AI cleanup by default — removes filler words, fixes grammar/punctuation, and supports "Emojify it" / natural emoji requests ("Add a sushi emoji," "Add some emoji") instead of requiring an exact emoji-name incantation.
- No explicit "raw vs polished" toggle was found — Rambler's cleanup appears to be the default behavior of that mode rather than a switch; the older base voice typing has no cleanup toggle mentioned either (it's mostly raw transcription plus spoken punctuation).

## Voice commands
See the dedicated **Full command list** section below for verbatim command phrases with citations. Summary of the command tiers:
1. **Base Gboard voice typing** — punctuation words only ("period," "comma," "exclamation point," "question mark," "new line," "new paragraph").
2. **Advanced voice typing (Pixel 6+)** — session control ("Stop," "Send," "Next"), deletion ("Delete last word," "Clear," "Clear all"), emoji-by-name ("Smiley emoji").
3. **Detailed edits (Pixel 8+)** — insert/delete/replace/spell/capitalize/undo commands targeting specific words.
4. **Writing tools voice commands (Pixel 9+, not 9a)** — rewrite-style commands (proofread, rephrase, formalize, casual, lengthen, shorten, "Use this," "Next"/"Previous" to page through rewrite options).
5. **Rambler (Pixel 11)** — conversational, non-memorized commands ("Make this sound more professional," "Change blue to green," "Add a sushi emoji") rather than a fixed phrase list.
6. **ChromeOS Dictation** — editing commands: "Type [word/phrase]," "Select all," "Cut," "Copy," "Paste," "Delete the previous character," "Undo," "Redo," "New line," cursor-movement commands, and "Replace [word/phrase] with [word/phrase]" — restricted to English, French, German, Italian, and Spanish.

## Languages & multilingual
- Rambler is the standout: 11 languages with **mid-sentence language switching** built in — the closest thing Google ships to Nasar Flow's Singlish/Malay/Arabic code-switching use case, though Malay isn't in its list (Arabic is).
- Pixel advanced voice typing's automatic language detection covers 6 languages (English, French, German, Italian, Japanese, Spanish) and is pitched as detecting "multiple languages simultaneously."
- Base Gboard voice typing supports many languages for plain transcription but explicitly does not support talk-to-text or full punctuation in all of them; no single canonical list was published on the crawled page.
- ChromeOS's advanced editing commands are limited to 5 languages (English, French, German, Italian, Spanish); base dictation requires the spoken language to match the device's configured language (no auto-detect implied there).
- No translation-while-dictating feature was found for any of these (Gboard has a separate "Translate as you type" feature, but it is a distinct typing feature, not part of voice typing).

## Privacy & data
- Rambler's help page states audio and text inputs are only **"temporarily processed"** and **"never saved, stored, or shared, and deleted immediately after your text is delivered,"** and explicitly disclaims that the system will refuse to generate CSAM, harassment, or hate-speech content — notable because it's the most explicit zero-retention language found across any of these products' docs.
- Pixel advanced voice typing's Writing Tools proofreading is stated to happen **on-device**, "ensuring data privacy" — a direct on-device privacy claim from Google.
- The Android `SpeechRecognizer`/`RecognitionService` on-device path (`createOnDeviceSpeechRecognizer`, `checkRecognitionSupport`) exists specifically so third-party apps can request local-only recognition and "reduc[e] dependency on cloud services and improv[e] privacy," per the API reference — this is the underlying platform capability other apps (including, in principle, Nasar Flow's competitors) can hook into instead of shipping their own recognizer.
- Per Android's own class documentation (https://developer.android.com/reference/android/speech/RecognitionService), `RecognitionService` is described as **"a base class for recognition service implementations. This class should be extended only in case you wish to implement a new speech recognizer."** Its three core lifecycle methods are `onStartListening` ("Notifies the service that it should start listening for speech" — implementers are told to create an attribution context for proper microphone-access tracking/blame assignment), `onStopListening` ("speech captured so far should be recognized as if the user had stopped speaking at this point"), and `onCancel` ("Notifies the service that it should cancel the speech recognition"). Support-checking (`onCheckRecognitionSupport`, added API 33-34) lets a service declare whether it can satisfy a given recognizer intent before a caller commits to it — the plumbing behind `SpeechRecognizer.checkRecognitionSupport()` on the client side.
- No retention/enterprise/SOC2/HIPAA claims were found for base Gboard voice typing, ChromeOS Dictation, or Samsung Keyboard in the pages crawled.

## Onboarding & docs
- Google's help content for this feature area is spread thin across small, single-purpose articles (one for base voice typing, one for "advanced" features, one for Rambler) rather than one consolidated page — a user has to know which Pixel-generation tier they're on to find the right article.
- Rambler has an explicit **in-product onboarding dialog** on first use (intro screen with a "Start" button) before the feature activates — the only one of these with a described first-run tutorial moment.
- ChromeOS Dictation onboarding is settings-driven: the user must proactively enable the Dictation accessibility toggle before the feature is reachable at all (it is not on by default), which is a real discoverability cost Google accepts in exchange for accessibility framing.
- No dedicated troubleshooting, known-issues, or status page was found for Gboard/Assistant voice typing or ChromeOS Dictation among the pages crawled.

## Changelog & velocity
- Rambler (Gboard help `answer/17468539`) is the newest entry in this family and is gated to the **Pixel 11** generation — consistent with Google's cadence of introducing a new voice-typing tier with each new flagship Pixel (advanced voice typing arrived with Pixel 6; detailed edits with Pixel 8; writing-tools voice commands with Pixel 9; Rambler with Pixel 11).
- The Android on-device `RecognitionService`/`SpeechRecognizer` on-device path was introduced with **Android 13 (API 33)**, per the API reference minimum-level note, even though it isn't called out as a headline feature on Android 13's own features overview page.
- No further release-note-level changelog (dated feature list over the last 6 months) was locatable on the crawled support pages — Google doesn't appear to publish a versioned changelog for Gboard voice typing specifically the way some third-party apps do.

## Blog / engineering insights
Beyond the API reference material (URLs 10–12 above), no Google engineering blog post specifically explaining the on-device recognition architecture, latency numbers, or evaluation methodology for Gboard/Assistant voice typing or Rambler was found within this research pass's search budget. This is a gap relative to some competitors who publish detailed "how it works" posts — worth another pass if deeper architecture detail becomes important.

## User complaints (reviews, Reddit, HN, App Store)
Search-engine access in this research pass repeatedly failed to surface individual Reddit/HN/App Store threads (search results kept collapsing to generic navigational pages rather than real discussion threads), so nothing here is backed by a specific crawled URL — treat this section as general, widely-corroborated pattern-matching rather than sourced fact, and re-verify before quoting externally:
- Voice typing tiers vary by exact Pixel model/OS version, which commonly confuses users about why a command that "should" work doesn't (e.g., Writing Tools voice commands excluded on the Pixel 9a).
- Base Gboard voice typing's punctuation-by-voice ("period," "comma," etc.) is frequently seen as clunky/dated compared to newer AI-cleanup competitors, which is part of why Google built Rambler.
- ChromeOS Dictation's advanced command set is locked to 5 languages, a recurring frustration for non-English/French/German/Italian/Spanish speakers who only get literal dictation with no editing-by-voice.
- Cloud dependency for full-quality Rambler (with a degraded offline mode) is a natural friction point for users expecting fully offline AI dictation — directly relevant to Nasar Flow's fully-offline pitch.

## Full command list

### Gboard voice typing — base commands
Source: https://support.google.com/gboard/answer/2781851?hl=en
- "Period"
- "Comma"
- "Exclamation point"
- "Question mark"
- "New line"
- "New paragraph"
(Page also notes emoji can be spoken and that punctuation availability varies by language; no further base commands were documented on this page.)

### Gboard advanced voice typing — Pixel-specific commands
Source: https://support.google.com/gboard/answer/11197787?hl=en

Session / basic control (Pixel 6+):
- "Delete last word"
- "Clear" (clears the last sentence)
- "Clear all" (clears all text)
- "Send"
- "Next"
- "Stop"
- "[Emoji name] emoji" — e.g. "Smiley emoji"

Detailed edits (Pixel 8+, English US):
- "Insert [text] before [reference]" / "Insert [text] at the end"
- "Delete [word]"
- "Change [word] to [word]"
- "Spell [name] as [spelled version]"
- "Capitalize [word]"
- "Undo"

Writing tools voice commands (Pixel 9+, excluding 9a):
- "Proofread this" / "Fix this"
- "Rephrase the message" / "Make my message clearer"
- "Formalize the text" / "Make my email more formal"
- "Make my text more casual"
- "Emojify it"
- "Lengthen my message" / "Make my email longer"
- "Shorten my text" / "Make it concise"
- "Use this"
- "Next" / "Previous" (to page through rewrite suggestions)

### Rambler voice input — command style (not a fixed phrase list)
Source: https://support.google.com/gboard/answer/17468539?hl=en

Rambler is explicitly conversational rather than fixed-syntax; documented examples include:
- "Make this sound more professional"
- "Make this shorter and more direct"
- "Change blue to green"
- "Add a sushi emoji"
- "Add some emoji"

### ChromeOS Dictation — commands
Source: https://support.google.com/chromebook/answer/12001244?hl=en
- "Type [word/phrase]"
- "Select all"
- "Cut"
- "Copy"
- "Paste"
- "Delete the previous character"
- "Undo"
- "Redo"
- "New line"
- Cursor-movement commands (unnamed specifics on the page)
- "Replace [word/phrase] with [word/phrase]"
(These commands work only in English, French, German, Italian, and Spanish per the page; base dictation requires the spoken language to match the device's set language.)

## Samsung Keyboard voice input (brief)
Samsung Keyboard (bundled with One UI) has long included a microphone key that hands off to voice-to-text input, but within this research pass's search budget I was **not able to locate a dedicated, crawlable Samsung support article** documenting its exact activation flow, command set, or language list (Samsung's support-site search endpoints returned static shells with no server-rendered results, and general web search kept surfacing Samsung's marketing pages instead of a specific how-to article — see the Facts section's URL list for the one Samsung hub page that was actually crawled). What's well established from Samsung's own in-product UX (not independently re-verified via a citable page in this pass) is that voice input is reached the same way as on stock Android — a microphone key on the keyboard, or a settings toggle under Samsung Keyboard → Voice input — and that on most Samsung devices this delegates to Google's speech recognition stack rather than a distinct Samsung-built engine, so its effective language coverage and (lack of) voice-editing commands generally track base Gboard/Android voice typing rather than adding Samsung-specific commands. This should be treated as **lower-confidence** than the rest of this document and revisited with a dedicated Samsung research pass (e.g., a direct crawl of Samsung Members community posts or a live device test) if Samsung Keyboard becomes a priority competitor to benchmark precisely.

## Best-practice takeaways
1. **Tiered feature-gating by hardware, communicated up front** — Google explicitly names which Pixel generation unlocks which command tier (6+, 8+, 9+ excluding 9a, 11) rather than silently failing; Nasar Flow should be equally explicit about what's available on which OS/device tier.
2. **"Speak now" is the entire activation affordance** — a single, unambiguous text cue rather than a complex UI; simple, low-friction pattern worth keeping for a minimal listening state.
3. **Named, memorable voice-typing "modes"** — "advanced voice typing," "Rambler" — give Google something to market and users something to ask for by name; Nasar Flow's dictation mode should have a nameable identity too.
4. **Conversational, non-memorized commands (Rambler)** beat a fixed phrase list for the "delete that / make it shorter" class of edits — natural language commands ("Make this sound more professional") lower the memorization burden versus Assistant voice typing's earlier exact-phrase commands ("Delete last word").
5. **Explicit zero-retention language** ("never saved, stored, or shared, and deleted immediately") is a strong, quotable privacy claim Google makes for its newest AI dictation feature (Rambler) — Nasar Flow's fully-offline story is an even stronger claim and should be stated with equal directness.
6. **Mid-sentence language switching as a named, tested capability** (Rambler's multilingual support) validates that code-switching dictation is a real, productized need — exactly Nasar Flow's core bet — rather than a niche edge case.
7. **On-device proofreading marketed as a privacy feature, not just a latency feature** — "Writing tools proofreading happens on-device, ensuring data privacy" is copy Nasar Flow can emulate almost verbatim, truthfully, for its whole pipeline.
8. **Graceful, visible offline degradation** rather than hard failure — Rambler's offline mode keeps "basic cleanup, punctuation, and capitalization" and shows a "Retry" button to get full quality back once online, instead of just erroring out.

## Ideas Nasar Flow should steal or beat
1. [steal] Ship a single, simple "Speak now" style activation cue with no ambiguity about whether it's listening — Google's simplicity here is a low bar but a correct one.
2. [steal] Name the AI-cleanup dictation mode distinctly (like "Rambler") so users and reviewers have a specific feature to talk about, rather than burying it as an unnamed setting.
3. [beat] Google's language coverage for *code-switching* tops out at Rambler's 11 languages with no Malay and only Arabic for the Gulf/MSA register — Nasar Flow's Singlish/Malay/Arabic-specific tuning is a real, defensible gap to beat on precision for South-East-Asian code-switching that Google's general-purpose multilingual model won't specifically target.
4. [beat] Google gates its best on-device AI dictation behind specific, expensive flagship hardware (Pixel 11 for Rambler, Pixel 9 non-a for writing tools) — Nasar Flow should make its best on-device experience available across a much broader device tier, turning hardware-gating into a selling point ("works fully offline on the phone you already have").
5. [steal] Offer graceful offline degradation with a clear affordance to "retry" for full quality once back online, rather than a hard error — but [beat] by making Nasar Flow's default (not fallback) mode the fully-offline one, inverting Google's cloud-first-with-offline-fallback model.
6. [beat] None of Google's crawled docs make a strong, specific claim about retention/processing guarantees for the *base* (non-Rambler) voice typing path most users actually have — Nasar Flow can make one unified, always-on privacy claim across its entire feature set instead of only its newest premium tier.
7. [steal] Conversational, natural-language edit commands (Rambler's "make this shorter," "change blue to green") over Assistant voice typing's older fixed-phrase command grammar — natural language is a genuinely better UX pattern worth adopting directly.
8. [beat] Google's help documentation for this whole feature area is fragmented across many small, hard-to-discover articles with no single "how it works end to end" page — Nasar Flow's docs/onboarding should consolidate this into one clear, well-indexed explanation of what dictation mode does what.
