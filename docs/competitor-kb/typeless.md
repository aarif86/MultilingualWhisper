# Typeless

> Made by Typeless (Simply CA LLC, Palo Alto, YC-backed, founder Huang Song); an AI voice dictation app ("voice keyboard") for macOS/Windows/iOS/Android that turns speech into cleaned-up, formatted text in any app — targets knowledge workers, engineers, founders, doctors who write a lot across many apps.

## Facts
- **Maker / founded / funding:** Typeless, legal entity Simply CA LLC, HQ Palo Alto, CA. Founder/CEO Huang Song (Stanford alum, serial entrepreneur). Backed by Y Combinator. Founding date not published.
- **Platforms:** macOS (Apple Silicon + Intel), Windows, iOS, Android. No Linux, no browser extension found. Desktop = system-wide dictation overlay; mobile = dedicated AI voice keyboard replacing the system keyboard.
- **Pricing:** Free tier — 8,000 words/week (after a 30-day trial period), standard accuracy, standard access during high demand. Pro — $12/mo billed yearly or $30/mo billed monthly, unlimited words, enhanced accuracy, priority access, cloud sync, team management, usage analytics, early feature access. Enterprise — custom/contact sales: SSO, SCIM/JIT provisioning, domain verification, audit logs, "Enforced HIPAA controls," BAA availability, volume discounts, priority support. (Source: https://www.typeless.com/pricing)
- **Engine:** Cloud-based, NOT on-device despite "on-device" marketing language. Per their own privacy policy: "audio inputs and contextual information are processed in real time on our cloud servers and immediately discarded once the transcription result is returned to your local device" (https://www.typeless.com/privacy). A November 2025 reverse-engineering writeup (via getvoibe.com) found voice data actually routes to AWS servers in us-east-2, and that "on-device" only describes where *transcription history* is stored locally, not where audio is processed. Uses third-party LLM providers for the cleanup/formatting layer (configured for zero retention per Typeless).
- **Languages:** 100+ languages, automatic detection, claims seamless mixed-language handling ("handles regional accents and mixed-language speech" — typeless.com/blog/typeless-vs-wispr-flow). Interface language setting separately supports 58 languages (https://www.typeless.com/help/quickstart/settings).
- **Docs / KB / blog / changelog URLs crawled:**
  - https://www.typeless.com/
  - https://www.typeless.com/help
  - https://www.typeless.com/help/faqs
  - https://www.typeless.com/help/quickstart
  - https://www.typeless.com/help/quickstart/settings
  - https://www.typeless.com/help/installation-and-setup
  - https://www.typeless.com/downloads
  - https://www.typeless.com/use-cases
  - https://www.typeless.com/about
  - https://www.typeless.com/pricing
  - https://www.typeless.com/privacy
  - https://www.typeless.com/help/release-notes
  - https://www.typeless.com/help/release-notes/macos
  - https://www.typeless.com/help/release-notes/ios
  - https://www.typeless.com/help/release-notes/android
  - https://www.typeless.com/blog
  - https://www.typeless.com/blog/typeless-vs-wispr-flow
  - https://spokenly.app/blog/typeless-review
  - https://www.getvoibe.com/resources/typeless-privacy-issues/
  - https://www.producthunt.com/products/typeless-2/reviews
  - https://adam.holter.com/typeless-android-keyboard-real-voice-to-text-without-the-cleanup/
  - https://apps.apple.com/us/app/typeless-ai-voice-keyboard/id6749257650
  - https://www.trustpilot.com/review/typeless.now
  - https://www.getvoibe.com/resources/typeless-review/
  (Note: https://www.typeless.com/help/quickstart/first-dictation and .../quickstart/key-features returned 404 at crawl time despite being indexed by search engines — likely renamed/removed pages; content partially recovered via search-result snippets, cited inline below.)

## Activation & capture UX
- Default hotkey: **Fn** on macOS, **Right Alt** on Windows (per indexed snippet of the now-404'd https://www.typeless.com/help/quickstart/first-dictation). Press once to start; cursor must already be focused in a text box.
- Feedback on activation: an "interaction sound" plays and/or a **voice bar** overlay appears once Typeless is listening.
- Settings (https://www.typeless.com/help/quickstart/settings) let users customize the shortcut per action — separate bindable shortcuts exist for **Dictate**, **Translate**, and **Ask Anything** — and add extra shortcuts for external keyboards. There's also an "Interaction sounds" toggle and a "Mute when dictating" option (pauses other system audio while recording).
- Mobile: Typeless installs as a system-wide **AI voice keyboard** (replaces the default keyboard row). On iOS this reportedly displaces the emoji key, a recurring user complaint (see Complaints section).
- No explicit "hands-free" or watch integration found in crawled pages.

## Text insertion
- Desktop: uses **Accessibility API** access — explicitly requested during setup: "Click Allow to let Typeless insert your spoken words into the active text field" (macOS System Settings → Privacy & Security → Accessibility). This is how it inserts into apps like Slack and Google Docs directly rather than via clipboard paste.
- Mobile: functions as a full keyboard extension (like a stock/Gboard replacement), so insertion is native keystroke-level, not paste.
- Claimed compatibility: "works across all apps," specifically lists Notability, Microsoft Teams, Outlook, Zoom, OneNote, Google Docs, Slack, Notion, ChatGPT, VS Code, WhatsApp, LINE, Gmail, Telegram, Discord, Word, Apple Notes, Obsidian, Notepad, TextEdit, Google Keep, PowerPoint, Cursor, Terminal, Perplexity, Grok, Claude, Codex — "and 60+ others."
- Selection/cursor handling: the "Ask Anything" / "Speak to Edit" feature explicitly operates on **selected text** (select text, then issue a voice command to shorten/change tone/rewrite it in place).
- No documented fallback behavior or list of known-broken apps found in crawled pages (worth further digging on Reddit/App Store if time allows).

## Accuracy & personalization
- **Personal Dictionary**: a persistent, per-user vocabulary list. "You can add common names, technical terms, or unique phrases to your Personal Dictionary — Typeless will prioritize them and recognize them consistently." Entries are added both automatically (system learns over time) and manually.
- Auto-learning: "Typeless remembers your specific vocabulary, turning it into a personalized tool that gets better the more you use it" — and per their Wispr-comparison blog post, Typeless "automatically learns specialized terms" without requiring manual dictionary entry (contrasted against Wispr Flow's manual-only dictionary).
- "Personalization" is also listed as adapting to the user's own **tone and phrasing habits** over time, not just vocabulary.
- Free tier explicitly gets only "standard accuracy" vs Pro's "enhanced accuracy" — accuracy itself is a paywalled tier, not just word volume.
- No mention found of importing contacts, screen-context-based name injection, or an explicit "spelling mode" — worth flagging as a gap vs claims (their privacy-issue writeup, however, shows Typeless AI Ask Anything.

## Formatting & AI cleanup
- Filler-word removal ("um," "uh," "you know"), removal of **repeated words**, and detection of **mid-sentence self-correction** (drops false starts/restarts automatically).
- Auto-formatting of spoken lists, steps, and key points into structured text (numbered lists, etc.) without manual line breaks.
- "Comprehends the meaning behind your words to optimize phrasing for clarity and flow" — i.e., it doesn't just transcribe verbatim, it rewrites for readability by default (no clear "raw" transcript toggle found in crawled docs, though a "Whisper mode" is listed as a Free-tier feature name with no description recovered — possibly a literal-transcription/quiet mode, worth follow-up).
- App-aware tone isn't confirmed as automatic; Product Hunt reviews explicitly complain that users want **context-aware output per app** (different formatting/tone for casual chat apps vs formal documents) — implying this is not yet fully automatic and is a known gap.

## Voice commands
- The 5 named quickstart features are, verbatim: **Dictate** ("Turn messy thoughts into polished writing"), **Translate** ("Turn your voice into ready-to-send translations"), **Ask Anything** ("Edit text, get answers, and take action with your voice on desktop"), **Speak to Edit** ("Edit text with voice on mobile"), and **Personalization** ("See how Typeless adapts to your unique style and tone") — per typeless.com/help/quickstart (recovered via search-index snippet after the live page 404'd at crawl time).
- Branded as **"Ask Anything"** (desktop) / **"Speak to Edit"** (mobile): select existing text, then speak a command to edit it — examples surfaced: shorten, change tone, translate, rewrite.
- Also supports general AI assistant behavior through the same voice trigger: "quick answers, brainstorming, and cross-site information retrieval" (i.e., voice commands aren't just text-editing, they can also fetch information/act, similar to an AI agent).
- Exact command phrase library (e.g. literal "delete that" / "new line" / "undo") was not found verbatim in any crawled page — Typeless's own docs describe capability categories ("shorten," "change tone," "translate") rather than a fixed command grammar. Flagged as an area needing a deeper doc crawl if precision matters.

## Languages & multilingual
- 100+ languages, automatic language detection (no manual switch needed).
- Claims to handle **mixed-language speech within a single utterance** ("mix them seamlessly," "handles regional accents and mixed-language speech" — typeless.com and typeless.com/blog/typeless-vs-wispr-flow) — directly the Nasar Flow use case (Singlish/Malay/Arabic code-switching).
- **Translate** is a first-class dedicated mode/shortcut (separate hotkey from Dictate): speak in one language, get output text in a different target language, "ready-to-send translations," described as instant/native-phrasing rather than literal.
- Interface (UI chrome) language support is a separate, smaller list (58 languages) from the dictation/transcription language support (100+).

## Privacy & data
- Marketing claims: "zero cloud data retention," "never trained on your data," on-device history storage, HIPAA compliant, GDPR compliant, ISO 27001 certified (per homepage + X posts from the company). Trust center at https://trust.typeless.com/ returned HTTP 403 to crawler (likely needs a logged-in/allowed viewer) — could not independently verify SOC2 status; third-party sources say "working toward SOC2 Type II."
- Actual privacy policy language (crawled https://www.typeless.com/privacy) confirms voice audio + "contextual information" (i.e., screen/app context) IS sent to and processed on Typeless's **cloud servers**, then "immediately discarded" post-transcription — meaning zero *retention*, not zero *transmission*. This is a meaningful nuance: audio always leaves the device.
- Independent reverse-engineering findings (via getvoibe.com, citing a Nov 2025 X analysis by @medmuspg): Typeless also captures browsing URLs (including Gmail/Google Docs page URLs), window titles, and focused-app names via macOS Accessibility APIs; requests screen recording, camera, and Bluetooth permissions beyond what dictation needs; stores transcribed text + URL metadata **unencrypted in a local plaintext database**; and routes voice data to **AWS us-east-2**. This directly contradicts the "on-device"/"private by design" framing used in Typeless's own marketing.
- Enterprise plan adds SSO, SCIM/JIT provisioning, domain verification, audit logs, "Enforced HIPAA controls," and BAA (Business Associate Agreement) availability for regulated customers.
- Opt-outs offered: marketing-email unsubscribe, Google Analytics opt-out add-on, NAI/DAA ad opt-out links, Google Ads Settings, and a toggle to disable cloud sync of dictation history.

## Onboarding & docs
- Onboarding: install → sign in (Google, Apple, email, or SSO for Enterprise) → grant **Accessibility** permission ("insert your spoken words into the active text field") → grant **Microphone** permission → test mic (a blue bar visually reacts to voice) → first dictation.
- Help center (typeless.com/help) is organized into exactly 6 top-level categories, each apparently a single hub article: Installation and setup, Quickstart, Troubleshooting, Billing, FAQs, Release notes (with release notes further split into macOS/Windows/iOS/Android sub-pages). This is a notably thin/shallow KB structure compared to competitors — no large searchable article library, just a handful of hub pages with sub-sections.
- Quickstart hub (typeless.com/help/quickstart) walks through: Dictate, Translate, Ask Anything (desktop), Speak to Edit (mobile), Personalization, History & Dictionary, Settings — implying this is the canonical feature list Typeless wants new users to learn first.
- Tone of docs: short, plain, action-oriented ("Click Allow...", "Drag the Typeless icon to Applications"), consumer-friendly rather than technical.
- No dedicated public status page or "known issues" page was found (distinct from release notes / troubleshooting hub).

## Changelog & velocity
- Release notes exist per-platform (macOS, Windows, iOS, Android) at typeless.com/help/release-notes/<platform>, but the crawler only recovered navigation/hub text — full changelog details had to be recovered via search snippets/social posts:
  - **v2.4.0** (iOS + Android): added a **Zhuyin keyboard** for Traditional Chinese input.
  - **v2.3.0** (macOS + Windows): added **"dictation insights"** — days active, streaks, longest streak, usage stats across days/weeks.
  - **v2.3.0** (iOS + Android): added **Dark Mode**.
- Cadence: appears to ship versioned feature updates fairly regularly (point releases with named features), consistent with an actively-iterating YC-stage startup, though exact dates for these versions weren't recoverable from the crawl.

## Blog / engineering insights
- Only one blog post was discoverable in English at crawl time: "Typeless vs Wispr Flow: Which AI Voice Keyboard Is Better in 2026?" (Aug 2, 2026, by Elena Brooks) — https://www.typeless.com/blog/typeless-vs-wispr-flow. This is a competitive/marketing post, not a technical engineering writeup — no latency numbers, model architecture, or evaluation methodology were disclosed. Claims made (self-reported, not independently verified): "4x faster than manual typing," "near-instant transcription," automatic specialized-vocabulary learning without manual dictionary entry, and superior multilingual/accent handling vs. Wispr Flow.
- Homepage repeats the throughput claim: "220 words per minute" speaking speed vs. "45 wpm" typing speed, and "saves ~1 day per week."
- No dedicated engineering blog, whitepaper, or model-choice disclosure was found — Typeless does not publicly discuss which ASR model(s) or LLM(s) power the product.

## User complaints (reviews, Reddit, HN, App Store)
- **Rating split by source is stark**: Apple App Store 4.5/5 (671 ratings), Google Play 3.9/5 (1,335 reviews per getvoibe.com), Product Hunt ~5.0/5, but **Trustpilot only 2.7/5** (9 reviews, 56% one-star) — Trustpilot skews toward billing/support complaints while app-store ratings skew toward feature praise, suggesting support/billing experience is a weak point distinct from the product itself.
- **Trustpilot-specific complaints**: unresponsive customer support ("waited hours without reply after payment," "no confirmation at all... following premium purchase"), difficulty finding support contact info, and "aggressive marketing tactics" — the app reportedly "randomly opens out of nowhere" / "opened a new tab" without user interaction, described by one reviewer as "scummy practices."
- **App Store-specific complaints**: unstable swipe-to-keyboard interaction, long dictations sometimes cut off recording prematurely, a bug that prevents screen lock while the app runs in background, the AI occasionally appending unsolicited content (e.g. unwanted closing phrases like "thank you"), and the mobile app lacking AI features that the desktop app has.
- **HIPAA transparency gap**: getvoibe.com's review notes "HIPAA compliance was announced March 2026 without a publicly advertised Business Associate Agreement," leaving ambiguity for regulated (e.g. healthcare) customers despite the compliance marketing claim.
- **No lifetime plan**: unlike some competitors (e.g. cited alternatives Voibe at $149 lifetime, VoiceInk at $29 one-time), Typeless is subscription-only — 3-year cost of Pro Annual is ~$432, Pro Monthly ~$1,080.
- **No offline/on-device mode**: "Every dictation needs a connection; there is no on-device mode on any platform" (spokenly.app review) — cited as a dealbreaker for privacy-conscious users and flights/poor connectivity.
- **Pricing**: $30/month month-to-month is called "the priciest tool in its class"; the discounted $12/mo rate requires an annual commitment (spokenly.app, usevoicy.com).
- **No BYOK / model choice**: "You cannot point Typeless at your own OpenAI account or choose the transcription model" (spokenly.app).
- **No coding-assistant integration**: lacks an MCP server for Claude Code/Cursor-style voice-driven coding workflows (spokenly.app).
- **iOS keyboard replaces the emoji key**, a specifically-named friction point in multiple negative App Store-style reviews (search-aggregated finding + adam.holter.com).
- **Lack of per-app/per-context personalization**: users on Product Hunt want different tone/formatting automatically depending on target app (casual chat vs. professional doc) — implying today's formatting is closer to one-size-fits-all than context-aware.
- **Privacy/marketing-claim gap**: independent researchers (getvoibe.com, citing X user @medmuspg) found cloud processing, broad permissions (screen recording/camera/Bluetooth), unencrypted local storage of transcripts+URLs, and AWS routing — all contradicting the "private/on-device" pitch.
- **Free-tier annoyance**: at least one review describes a "super annoying pop-up window for free plan users making the app unusable" (from HN/App-store aggregated complaints via WebSearch).
- **Android lag**: historically iOS-first; Android support/parity has been a repeated feature request, though Android now exists (Play Store listing found) — some review sources are simply out of date on this point.

## Best-practice takeaways
1. **Per-action hotkeys, not one global toggle** — Typeless lets users bind separate shortcuts for Dictate, Translate, and Ask Anything, plus supports extra bindings for external keyboards. Nasar Flow could similarly let users assign distinct shortcuts once a hotkey-based desktop mode exists.
2. **"Ask Anything" / "Speak to Edit" as a named, discoverable feature** — select text, then voice-command an edit (shorten, change tone, translate). Giving this pattern an exact memorable name (not just "voice commands") makes it marketable and teachable in one line of docs.
3. **Personal Dictionary is dual-mode**: both auto-learned from usage and manually editable. Ship both mechanisms, not just one — auto-learning alone can't be audited/corrected by the user, and manual-only doesn't scale.
4. **Dedicated Translate mode as a first-class action**, distinct from Dictate, with its own hotkey — not just an automatic byproduct of multilingual detection. For Nasar Flow's Malay/Arabic/English audience this could be a standalone advertised feature, not a buried setting.
5. **"Dictation insights" (v2.3.0)** — streaks, days active, usage stats — is a lightweight gamification/retention feature that costs little to build and gives users a reason to open the app between dictation sessions.
6. **Tiered accuracy as a pricing lever** — Free = "standard accuracy," Pro = "enhanced accuracy." Explicitly naming an accuracy tier (rather than just word caps) is a monetization pattern worth understanding even if Nasar Flow doesn't adopt paywalled accuracy.
7. **Radically thin help center works** — 6 hub pages covering Install/Quickstart/Troubleshooting/Billing/FAQ/Release-notes is apparently sufficient at Typeless's stage; Nasar Flow doesn't need to over-invest in KB depth before product-market fit.

## Ideas Nasar Flow should steal or beat
1. **[steal] Named voice-edit mode ("Ask Anything"/"Speak to Edit")** — even a minimal "select text, speak a fix" flow, clearly named, would differentiate Nasar Flow's Whisper-based app once voice-commands are built. Nasar Flow currently has no voice commands at all — this is the single biggest UX gap vs. Typeless.
2. **[beat] Genuine on-device processing** — Typeless *markets* "on-device"/"private by design" but independent research shows audio is actually sent to AWS cloud servers and only discarded after use; screen/URL context is also captured. Nasar Flow's whisper.cpp is genuinely fully offline/on-device. This is a real, defensible, honestly-claimable advantage — market it explicitly and contrast it against Typeless's documented claim/reality gap (cite the getvoibe.com / @medmuspg findings) rather than making a vague "we're private too" claim.
3. **[steal] Explicit dual-hotkey model (Dictate vs Translate as separate actions)** — once Nasar Flow ships a macOS/Windows hotkey mode, give Translate its own bindable shortcut rather than folding it into a settings toggle, matching how Typeless treats it as equally first-class as Dictate.
4. **[beat] Real code-switching vs "mixed-language" marketing copy** — Typeless claims to "handle mixed-language speech" but offers no technical detail or benchmark; Nasar Flow's entire premise is Singlish/Malay/Arabic code-switching as a *named specialty*, not a bullet point. Publish concrete before/after transcript examples (with real dialect phrases from native speakers, not synthesized ones) to prove it where Typeless only asserts it.
5. **[steal] Personal Dictionary that's both auto-learned AND manually editable** — Nasar Flow ships no custom vocabulary yet; even a manual add-word list (before attempting auto-learning) would close a real gap, especially for proper nouns and Malay/Arabic loanwords that whisper.cpp's base vocabulary mishandles.
6. **[beat] Honest accessibility-API insertion vs manual copy/paste** — Typeless inserts directly via OS Accessibility APIs on desktop and as a true keyboard extension on mobile; Nasar Flow currently relies on manual copy/paste on iOS. Since Nasar Flow already has a system keyboard extension (per project docs), prioritize direct-insert parity there, and be transparent in docs about where Nasar Flow still requires copy/paste (matching Typeless's own thin-but-honest docs style: "Why do we ask for these permissions" is a good FAQ pattern to copy verbatim in framing, even though the permissions requested would differ).
7. **[steal] Tier accuracy/features around word volume AND a "standard vs enhanced" quality knob**, so if Nasar Flow ever introduces optional larger on-device Whisper models (base vs large), it can frame that exactly like Typeless's Free/Pro accuracy split — "standard" (smaller/faster local model) vs "enhanced" (larger local model) — while still being 100% on-device, beating Typeless's cloud-gated accuracy tier.
8. **[beat] Don't request permissions you don't need.** The strongest anti-Typeless talking point uncovered here is over-broad permission requests (screen recording, camera, Bluetooth) unrelated to dictation. Nasar Flow should audit and publicly document exactly which permissions it requests and why (one line each), and keep the list minimal — turning "we ask for less than Typeless" into a citable trust signal.
9. **[beat] Support responsiveness as a differentiator.** Typeless's app-store ratings (4.5/5 App Store, 3.9/5 Google Play) look strong, but Trustpilot — where billing/support disputes get aired — sits at just 2.7/5 with complaints of no response after payment and no purchase confirmation. As a small/early team, Nasar Flow can win real trust by simply replying fast and confirming every transaction; this is cheap to execute and Typeless is visibly failing at it on at least one review channel.
