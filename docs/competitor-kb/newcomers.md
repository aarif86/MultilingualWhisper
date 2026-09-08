# Newcomers: smaller/newer AI dictation entrants (2025–2026)

> Scope: compact per-app sections on the wave of small, often solo-founder or 2-person-team dictation apps that launched or gained traction in 2025–2026, distinct from the established players covered elsewhere in this KB (Wispr Flow, Superwhisper, Typeless, Monologue, Aqua Voice, VoiceInk, Willow Voice, MacWhisper, Serenade, Talon). Context throughout: **Nasar Flow** is an offline whisper.cpp iOS+Android dictation keyboard for Singlish/Malay/Arabic — takeaways are written against that positioning.

---
## Voicy (usevoicy.com)

**Facts**
- Maker: small team, cross-platform focus. Platforms: Mac, Windows, Linux, iOS, Android, Chrome extension.
- Engine: **cloud-only**, powered by Groq/Whisper V3 — no offline mode.
- Pricing: $8.49/mo (annual, 20% off), $260 lifetime, Teams $6.79/user/mo (min 3 seats). 20% student/disability discount.
- Free cap: 30 minutes of recording, one-time (not recurring monthly).

**Distinctive features**: "AI rewriting and editing," 50+ languages with auto-detect, integrates with 20,000+ websites/apps (Gmail, Docs, Slack, Word, Outlook, ChatGPT named explicitly), transcripts "stored locally only" even though transcription itself is cloud-run.

**Positioning claim (verbatim)**: "Dictate everywhere with over 99% accuracy" / "3x faster than typing."

**Complaints**: No offline mode despite privacy framing (transcript storage is local, but audio still round-trips to Groq's cloud for the actual STT) — reviewers flag this as a privacy-messaging mismatch. [usevoicy.com/dictation-app](https://usevoicy.com/dictation-app)

**Takeaways for Nasar Flow**
1. [beat] Voicy markets "privacy" on local *transcript* storage alone while audio still leaves the device for STT — Nasar Flow's actual on-device whisper.cpp pipeline is a strictly stronger, honestly-claimable privacy story; say so explicitly in comparison copy.
2. [steal] The 20,000+ app/site integration count is a marketing number worth having an equivalent for (even "works in every text field system-wide" framing) since buyers scan for it.
3. Lifetime pricing ($260) sits far above the on-device-lifetime norm (~$40–150) — cloud-dependent apps charge lifetime prices assuming ongoing API cost pass-through; Nasar Flow's true on-device cost structure supports undercutting this.

---
## Utter (utter.to)

**Facts**
- Maker: small team; App Store id6753176013, Google Play com.arran.dicta. Platforms: Mac (14.4+, Apple Silicon for on-device), iPhone (17.0+), Android.
- Engine: **hybrid** — on-device local models (Apple Silicon only) or Utter Pro cloud with latest models; BYOK (OpenAI/others) supported without a subscription.
- Pricing: Free tier (20 min/week on official pricing page; homepage also frames free as "use local models or your own API key, no subscription needed"). Pro $9.99/mo or $79.99/yr (site) — homepage copy elsewhere cites $5/mo, $59.99/yr, suggesting a promo/regional price split.
- Free cap: 20 minutes/week (Pro-plan free tier).

**Distinctive features**: **AI Modes** (rewrite into email/notes/summary/chat), **Auto Edits** (filler removal, grammar, URL/phone formatting), **Custom Replacements** ("jon do" → "John Doe"), **Voice History** (searchable synced transcript library), speaker-separated meeting transcripts, file transcription + link summarization (YouTube/PDF/RSS).

**Positioning claim (verbatim)**: "Speak Naturally. Write Perfectly." — dictation framed as 220 wpm vs a 45 wpm typing baseline (~4x).

**Complaints**: On-device mode gated to Apple Silicon only (Intel Macs excluded); comparison pages it publishes itself (vs Wispr Flow, Handy, BetterDictation, Superwhisper, SpeakMac) suggest active competitive pressure/positioning defense in a crowded niche. [utter.to](https://utter.to/), [utter.to/blog/utter-vs-wispr-flow](https://utter.to/blog/utter-vs-wispr-flow/)

**Takeaways for Nasar Flow**
1. [steal] "Custom Replacements" for jargon/proper nouns is a cheap, high-value personalization feature — directly applicable to Singlish proper nouns, Malay names, and Arabic transliteration variants.
2. [steal] Publishing head-to-head comparison pages against every named competitor is standard practice in this niche now — worth doing for Nasar Flow vs. Wispr Flow, Superwhisper, Voicy for SEO + credibility.
3. [beat] Utter's on-device story is Apple-Silicon-only and Mac/iPhone-only; Nasar Flow's fully offline whisper.cpp on both iOS *and* Android, with no hardware-tier gate, is a broader and more honest "on-device everywhere" claim.

---
## aidictation.com

**Facts**
- Maker: small team (GitHub org "writingmate"). Platforms: Mac, Windows, iPhone, Android.
- Engine: **auto/hybrid** — "Auto mode automatically selects the optimal engine," online uses best cloud models, offline runs on-device recognition.
- Pricing: Free 2,000 words/month (no card required); unlimited $8.49/month.
- Free cap: 2,000 words/month.

**Distinctive features**: mid-sentence language switching across 99+ languages, "writing rules and spoken shortcuts," personal vocabulary/replacements, AI cleanup (fillers, false starts, grammar) before text renders.

**Positioning claim (verbatim)**: "Speak. It types."

**Complaints**: Runs its own "Dragon Dictation Cost" and "best offline dictation" comparison/buyer's-guide content marketing (aidictation.com/blog) — a pattern of content-driven acquisition rather than product differentiation; no unique architecture claim beyond "auto mode picks the engine." [aidictation.com](https://aidictation.com/)

**Takeaways for Nasar Flow**
1. Mid-sentence language switching (99+ languages) is explicitly marketed — this is core to Nasar Flow's Singlish/Malay/Arabic code-switching use case; make sure Nasar Flow's own code-switch handling is demoed just as explicitly, not left implicit.
2. [beat] "Auto mode" quietly falling back to cloud when online undercuts an "offline-first" claim — Nasar Flow should be unambiguous that it is offline-first/always, not "offline when convenient," as a trust differentiator.
3. The low free cap (2,000 words/month) is typical for cloud-cost-bearing free tiers; an on-device app has no per-word cloud cost, so Nasar Flow can credibly offer an uncapped free tier as a headline differentiator.

---
## Voibe (getvoibe.com) — also a prolific review/comparison site

**Facts**
- Maker: small team. Platforms: Mac, Windows.
- Engine: **platform-split** — Mac runs fully on-device/local; Windows runs in "fast, zero-retention cloud mode" (no Windows on-device option yet as of 2026).
- Pricing: $7.50/mo, $59/yr, $149 lifetime; Teams $6/seat/mo or $49/seat/yr (min 3 seats).
- Free cap: 7-day trial, no ongoing free tier with a cap (i.e., no freemium — trial-then-pay model).

**Distinctive features**: single "Pro" plan identical price/feature set on both OSes; Developer Mode; custom vocabulary; 30-day no-questions refund guarantee (hi@getvoibe.com).

**Positioning claim (verbatim)**: "Voibe replaces your keyboard with your voice — private by design, on Mac and Windows."

**Complaints**: The "private by design" claim is only true on Mac; Windows users are silently routed to cloud processing, which is a material gap between marketing headline and platform-specific reality. Also operates getvoibe.com/resources as a heavily-SEO'd competitor review/comparison hub (reviews of Voicy, Spokenly, Typeless, "Best Mac Dictation Alternatives," etc.) — i.e. Voibe is simultaneously a product and a competitive-intelligence content farm about its own rivals, rating itself favorably in its own comparisons. [getvoibe.com/pricing](https://www.getvoibe.com/pricing/), [getvoibe.com/resources](https://www.getvoibe.com/resources/)

**Takeaways for Nasar Flow**
1. [beat] "Private by design" that quietly isn't true on one platform is exactly the credibility gap Nasar Flow avoids by being genuinely offline on both iOS and Android — lean hard into "same privacy guarantee on every platform we ship" as a stated policy, not just a feature.
2. Voibe's self-published comparison-content strategy (dozens of "X vs Voibe" and "best X alternatives" pages) is clearly working as an acquisition channel for this whole niche — worth tracking getvoibe.com/resources periodically as a proxy for what the *entire* newcomer field is doing, since it reviews most of them.
3. A flat 30-day unconditional refund is a low-cost trust signal smaller apps use in lieu of longer track records; consider for Nasar Flow's paid tier if/when one exists.

---
## Spokenly (spokenly.app)

**Facts**
- Maker: small team. Platforms: Mac, iPhone (with custom keyboard), Windows, Linux.
- Engine: **hybrid, unusually generous** — on-device Whisper and Parakeet models free forever (no word caps, no trial clock, no card); Pro unlocks managed cloud (GPT-4o Transcribe, Deepgram Nova 3, Soniox) or BYOK to OpenAI/Deepgram/Groq/ElevenLabs/Mistral etc. at no markup.
- Pricing: Pro $9.99/month. On-device tier is free indefinitely.
- Free cap: **none** for on-device use.

**Distinctive features**: built-in **MCP server** so AI coding agents (e.g., Claude Code) can receive voice input directly; **Agent mode** for macOS automation; bash script hooks; file transcription with subtitle export; iOS custom keyboard.

**Positioning claim**: markets itself via comparison pages as the free, no-cap on-device alternative to paid competitors (e.g., "Free Dictation vs $8.49/mo Cloud" framing against Voicy).

**Complaints**: Pro cloud tier pricing/feature mix is complex to compare against pure on-device or pure cloud competitors since it's positioned as "best of both," which some comparison sites flag as harder to evaluate at a glance. [spokenly.app/pricing](https://spokenly.app/pricing), [getvoibe.com/resources/spokenly-review](https://www.getvoibe.com/resources/spokenly-review/)

**Takeaways for Nasar Flow**
1. [steal] The **MCP server for AI coding agents** is a genuinely novel distribution wedge — voice input into Claude Code / other agentic tools is a distinct, growing use case; worth evaluating whether Nasar Flow (or a companion tool) should expose a similar hook for developer/agent workflows.
2. [steal] "Free forever, no caps, no card" for the on-device tier — since on-device carries no incremental cloud cost, Spokenly proves the market accepts (and rewards) uncapped free on-device tiers; strengthens the case for Nasar Flow doing the same.
3. Uniquely broad BYOK provider list (6+ providers) with "we charge nothing on top" — a transparent-cost stance Nasar Flow could mirror if it ever adds an optional cloud fallback tier.

---
## BetterDictation

**Facts**
- Maker: small/solo. Platform: **macOS only**, Apple Silicon required (M1+, no Intel support).
- Engine: on-device Whisper on Apple Neural Engine for core transcription; Pro-tier AI cleanup (stammer correction, auto-formatting, grammar) routes text through OpenAI's API — i.e., **on-device STT but cloud-processed polish**.
- Pricing: Lifetime $39 (individual); Flex $49 + $2/mo Pro (3 devices); Studio $149 + Pro (10-seat team).
- Free cap: not a freemium product — paid lifetime license model, trial terms not detailed in crawled pages.

**Distinctive features**: named Pro add-ons "stammer correction," "automatic formatting," "grammar cleanup" — explicitly marketed as processing verbal tics out of transcripts.

**Positioning claim**: professional-grade, push-to-talk simplicity, 100+ languages, Whisper-on-Neural-Engine framing as the core sell.

**Complaints**: Intel Mac users fully excluded ("out of luck"); the privacy story is bifurcated exactly like Voibe's — raw transcription is on-device, but the moment you use any Pro AI feature (the actual value-add layer), text leaves the device to OpenAI. Reviewers/comparison sites call this out specifically. [betterdictation.com](https://betterdictation.com/), [spokenly.app/comparison/better-dictation](https://spokenly.app/comparison/better-dictation)

**Takeaways for Nasar Flow**
1. [beat] This is the second app in this set (with Voibe) where "on-device" only covers raw STT and the actual polish/cleanup step silently goes to the cloud — a recurring industry pattern. Nasar Flow should be explicit and specific: which pipeline stages (STT, punctuation, cleanup, voice commands) are on-device, not just a blanket "on-device" badge.
2. Named, marketable Pro features like "stammer correction" show granular feature-naming sells better than generic "AI cleanup" — Nasar Flow should name its Singlish/dialect-specific cleanup steps distinctly (e.g. a named "lah/leh particle handling" or similar, sourced from actual native-speaker phrasing per the project's dialect-authenticity rule).
3. Device-tier gating (Apple Silicon only) is a recurring complaint across this whole cohort — Nasar Flow running whisper.cpp across a wider range of iOS/Android hardware is a real accessibility/reach advantage worth quantifying (min OS/RAM supported) in comparison materials.

---
## Voice Type (voicetype, Mac)

**Facts**
- Maker: small/solo (App Store id6736525125). Platform: **Mac only**.
- Engine: fully **on-device**, runs Whisper locally; five selectable model sizes (Small/Medium/Large-v3-Turbo, in balanced/high-accuracy/max-accuracy builds).
- Pricing: **$19.99 once**, 7-day free trial, no subscription, no account required.
- Free cap: 7-day full-feature trial, then one-time purchase (not a recurring free tier).

**Distinctive features**: hold-to-talk/release-to-insert global shortcut; spoken punctuation/formatting commands ("comma," "new paragraph"); custom vocabulary for names/brands/acronyms; explicit model-size choice exposed to the user (accuracy/speed tradeoff as a setting, not hidden).

**Positioning claim (verbatim)**: "Your words appear right where your cursor is" / no internet required, audio never leaves the Mac.

**Complaints**: Mac-only, no mobile/Windows presence at all, limiting its addressable market versus cross-platform newcomers. [apps.apple.com id6736525125](https://apps.apple.com/us/app/voice-type-local-dictation/id6736525125)

**Takeaways for Nasar Flow**
1. [steal] Exposing Whisper model-size choice directly to users (speed vs. accuracy) rather than hiding the tradeoff is a good transparency pattern Nasar Flow could offer as an advanced setting for power users on capable devices.
2. A genuinely simple "$19.99 once, no account, no subscription" model is a clean trust/privacy signal (no account = no server-side identity to leak) — relevant if Nasar Flow ever monetizes; "no account required" is itself marketable.
3. [beat] True single-platform (Mac-only) reach-limitation is the inverse of Nasar Flow's iOS+Android coverage — worth stating "one app, both mobile platforms, same offline guarantee" as a differentiator against this whole single-OS cohort.

---
## Voquill

**Facts**
- Maker: open-source project (github.com/jackbrumley/voquill and a separate github.com/voquill/voquill org); listed on Product Hunt as "the open source alternative to WisprFlow." Platforms: macOS, Windows, Linux (desktop) + iOS app (App Store id6759206881) functioning as a system-wide AI voice keyboard.
- Engine: **user's choice** — run Whisper locally (optional GPU accel) or point at any cloud provider; open-source core.
- Pricing: **free**, no subscription on iOS, no card required; core dictation + AI cleanup free.
- Free cap: none reported — free/open-source core with optional self-supplied cloud API costs.

**Distinctive features**: works as a system keyboard in iMessage/WhatsApp/Slack/Gmail/LinkedIn/Reddit/Notes and "any other app where you can type"; personal glossary + replacement-rule sync; filler/false-start removal.

**Positioning claim**: explicitly branded on Product Hunt as "the open source alternative to WisprFlow."

**Complaints**: not found in crawled sources (early-stage/low review volume); inherent open-source risk of inconsistent maintenance is implied by the two separate GitHub orgs (jackbrumley/voquill vs voquill/voquill) suggesting a fork/rename history. [producthunt.com/products/voquill](https://www.producthunt.com/products/voquill), [github.com/jackbrumley/voquill](https://github.com/jackbrumley/voquill)

**Takeaways for Nasar Flow**
1. Being explicitly positioned as "the open-source Wispr Flow" is a clear, ownable niche in this market — Nasar Flow could similarly claim "the open[-ish]/offline-first Wispr Flow for Southeast Asian languages" as sharp, comparison-anchored positioning.
2. [steal] Working as a literal system keyboard across messaging/email/social apps (not just a floating overlay) matches Nasar Flow's own keyboard-extension approach — validates that model as a mainstream expectation, not a workaround.
3. BYO-cloud-or-local user choice, exposed plainly, is worth considering as a future "advanced" toggle even for a primarily offline-first product, for users who want higher accuracy on a public/shared device.

---
## Speakflow — NOT a dictation app (out of scope, noted for the record)

speakflow.com is a **teleprompter** with voice-activated scrolling, not a speech-to-text dictation tool. Free plan: unlimited scripts + voice-activated scrolling; paid plans add video recording. Included here only to document that the name collision exists and this product should not be confused with a dictation competitor. [speakflow.com/pricing](https://www.speakflow.com/pricing)

---
## Dictation Daddy (dictationdaddy.com)

**Facts**
- Maker: small team. Platforms: Mac, Windows, Chrome extension, Android (native); iOS "coming soon" as of crawl date.
- Engine: cloud-based (no on-device claim found in crawled pages).
- Pricing: Solo from $8/mo (annual) or $15/mo (monthly); Team from $12/mo (annual) or $18/mo. 7-day free trial, no card required.
- Free cap: trial-based, not an ongoing free tier.

**Distinctive features**: medical-terminology transcription mode; "learns individual writing styles and tones"; multilingual with language-switch recognition mid-dictation; 96–98% accuracy claim "with zero training."

**Positioning claim**: professional/business dictation across mainstream office tools (email, messaging, doc creation).

**Complaints**: iOS still unavailable as of the crawled pages despite Android/desktop parity — an incomplete cross-platform story for a paid product. [dictationdaddy.com/pricing](https://www.dictationdaddy.com/pricing), [dictationdaddy.com/windows](https://www.dictationdaddy.com/windows)

**Takeaways for Nasar Flow**
1. Medical-terminology and professional-tone personalization show vertical-specific vocabulary packs are a monetizable feature category — a potential future add-on direction (e.g. a Malay/Arabic religious or professional-register vocabulary pack).
2. [beat] Missing iOS at this stage of the product's life is a real gap; Nasar Flow shipping both mobile OSes from day one is worth stating plainly as parity, not an afterthought.
3. Team pricing tiers ($12–18/seat) show a B2B upsell path exists in this category even for consumer-first dictation apps — worth keeping on the roadmap radar, low priority.

---
## Tuny — not found

No dictation/voice-typing product named "Tuny" could be located via search (results returned unrelated voice-recorder/auto-tune apps). Likely either not yet indexed, a very recent/regional launch, or a name variant not matching search terms tried. Flagging as unresolved rather than fabricating detail.

---
## Murmur (murmur-app.com / murmurvt.com)

**Facts**
- Maker: small team, two branded domains (murmur-app.com for Mac, murmurvt.com for Windows) suggesting a split Mac/Windows product line. Platforms: Mac, Windows (Microsoft Store listed).
- Engine: **fully on-device**, built on OpenAI's Whisper, "no internet connection needed and no audio leaves your computer."
- Pricing: €39.97 lifetime or €2.48/month; free tier with 5 daily dictations, no card required; 7-day Pro trial.
- Free cap: 5 dictations/day.

**Distinctive features**: 95%+ accuracy claim; native Apple Silicon support; positions its lifetime price explicitly against Superwhisper's $129 lifetime as a cheaper alternative.

**Positioning claim**: "best voice typing app for Mac"/"for Windows" (separate SEO-targeted claims per platform via separate blog properties).

**Complaints**: none specific found in crawled pages; the split-domain (murmur-app.com vs murmurvt.com) branding could confuse users searching for one canonical product. [murmur-app.com](https://murmur-app.com/en), [murmurvt.com](https://murmurvt.com/)

**Takeaways for Nasar Flow**
1. A small (5/day) but real free tier with no card, alongside a modest lifetime price, is a template worth benchmarking Nasar Flow's own free-tier generosity against, since Murmur is positioned as a value/budget option specifically vs. premium on-device apps like Superwhisper.
2. [steal] Direct lifetime-price-vs-competitor framing ("40% cheaper than Superwhisper lifetime") is a simple, quotable comparison tactic for future Nasar Flow marketing if it ever sells a paid tier.
3. Running separate Mac and Windows marketing sites/blogs under different domains for SEO is a tactic to note, though likely not relevant for Nasar Flow's single cross-mobile-OS product.

---
## Whisper Flow (Butterfly AI LLC) — distinct from Wispr Flow

**Facts**
- Maker: Butterfly AI LLC. Not to be confused with Wispr Flow (Wispr AI, covered in `wispr-flow.md`) — direct naming collision in the category. Platforms: iPhone, Android, macOS (per whisperflow.org and its App Store listing id6754533870).
- Engine: not fully detailed in crawled pages; marketed as "AI voice keyboard."
- Pricing: marketed as **free** for iPhone, Android, and macOS.
- Free cap: not specified in crawled pages (appears free without a stated cap).

**Distinctive features**: functions as an actual voice keyboard (not just an overlay) across all three platforms; "turns speech into clean, formatted text inside any app."

**Positioning claim (verbatim)**: "AI voice keyboard app... turns your speech into accurate, formatted text inside any app... faster than typing... free for iPhone and Android and macOS."

**Complaints**: The name collision with the much larger, well-funded Wispr Flow is itself a source of user/press confusion (search results conflate the two); no independent complaint data surfaced separately from Wispr Flow's own reviews in this crawl. [whisperflow.org](https://whisperflow.org/), [9to5google.com Wispr Flow Android coverage](https://9to5google.com/2026/02/23/flow-dramatically-improves-android-voice-typing-without-replacing-gboard/)

**Takeaways for Nasar Flow**
1. Naming collisions are a real risk in this space (Whisper Flow vs Wispr Flow, Voice Type vs VoiceType/VoiceType AI) — worth a quick trademark/name-clash check for "Nasar Flow" itself against existing "Flow"-branded dictation apps before further brand investment.
2. Separately, Wispr Flow's actual Android approach (a floating bubble that appears in any text field rather than a full keyboard replacement, per 9to5Google) is worth noting as a UX alternative to Nasar Flow's keyboard-extension approach — floating-bubble avoids the "switch default keyboard" friction entirely; worth a deliberate note on why Nasar Flow chose the keyboard-extension route instead (deeper text-field integration, works with hardware keyboards, etc.) if that tradeoff hasn't been documented elsewhere in this KB.
3. A "free with no stated cap, cross-platform" entrant this recent shows how fast the free/on-device end of this market is being commoditized — reinforces urgency for Nasar Flow to lead on the Singlish/Malay/Arabic language quality it's uniquely positioned for, since raw "free dictation" is no longer a differentiator on its own.

---
## Talknotes (talknotes.io) — voice notes, dictation-adjacent

**Facts**
- Maker: small team. Platforms: iOS/Android app (Google Play com.talknotes.app) + web.
- Engine: cloud-based (record → transcribe → AI-styled note).
- Pricing: freemium; paid tiers not itemized in crawled pages (subscription-based, exact figures not surfaced).
- Free cap: up to 2 hours of recording time per note on the free plan; unlimited notes.

**Distinctive features**: three-step flow "record → choose a style → edit/organize"; branded style-based note transformation (turning a raw ramble into a structured note in a chosen style) rather than raw transcription; positioned for brainstorming, content creation, journaling, lecture-to-study-notes, interview transcription.

**Positioning claim**: "The #1 AI voice note app."

**Complaints**: exact paid pricing not published/found clearly in crawled pages — comparison sites note this makes it harder to evaluate against competitors at a glance. [talknotes.io/pricing](https://talknotes.io/pricing), [voicenotes.com/blog/talknotes-vs-voicenotes](https://voicenotes.com/blog/talknotes-vs-voicenotes)

**Takeaways for Nasar Flow**
1. Talknotes is a **voice-notes/journaling** product, not a live-dictation-into-any-app keyboard — it's a different category (post-hoc note capture vs. real-time inline typing). Relevant mainly as a reminder that "voice notes" and "dictation keyboard" are adjacent but distinct markets; Nasar Flow shouldn't blur its own positioning between the two.
2. The "choose a style" transformation step (turning a ramble into a structured note) is a feature pattern worth watching if Nasar Flow ever adds a longer-form "voice memo → structured text" mode beyond inline dictation.
3. Generous 2-hour-per-note free cap on a cloud product shows willingness to eat cost for word-of-mouth growth — again reinforces that Nasar Flow's zero-marginal-cost on-device model can beat this without even trying hard.

---
## Other 2025–2026 launches spotted during this crawl

- **Wave** (Product Hunt, macOS) — "Turn your voice into text — local or cloud, your choice." Hotkey-triggered, invokes an AI model anywhere on macOS; hold-to-speak-release-to-process UX. Notable for offering a genuine local/cloud toggle as a first-class choice rather than a hidden implementation detail. [producthunt.com/products/wave-16](https://www.producthunt.com/products/wave-16)
- **Yap** (Show HN, macOS) — small open-source menu-bar app, on-device voice-to-text via hotkey, pastes into the focused field, "no model to download" (bundles/fetches automatically). Everything local. [news.ycombinator.com/item?id=49073834](https://news.ycombinator.com/item?id=49073834)
- **Qwen Scribe** (Show HN, Apple Silicon) — local transcription/dictation built on Qwen models rather than Whisper, signaling the on-device-model race is no longer Whisper-exclusive. [news.ycombinator.com/item?id=49098260](https://news.ycombinator.com/item?id=49098260)
- **LumeVoice** — cloud-hybrid, claims fastest average latency (~0.3s) among alternatives surveyed by third-party comparison sites; positioned as a speed-first Wispr Flow alternative. [lumevoice.com/blog/top-9-wispr-flow-alternatives](https://lumevoice.com/blog/top-9-wispr-flow-alternatives/)
- **DictaFlow** (dictaflow.io) — cross-platform (Windows/Mac/iPhone) dictation app appearing repeatedly in comparison-site crawls alongside Wispr Flow/Superwhisper; positioning centers on "AI Dictation for Windows, Mac & iPhone." [dictaflow.io](https://dictaflow.io/)
- **DictaType** (dictatype.com) — $14.99 one-time lifetime license, appears repeatedly in "what dictation software costs" roundups as a budget one-time-purchase anchor point. [dictatype.com/blog/what-dictation-software-costs-2026](https://dictatype.com/blog/what-dictation-software-costs-2026/)

---
## Comparison table

| App | Platforms | On-device? | Price | Free cap | One-line differentiator |
|---|---|---|---|---|---|
| Voicy | Mac/Win/Linux/iOS/Android/Chrome | No (cloud, Groq/Whisper V3) | $8.49/mo · $260 lifetime | 30 min, one-time | Broadest platform count; local transcript storage marketed as "privacy" despite cloud STT |
| Utter | Mac (Apple Silicon)/iPhone | Partial (Mac Apple Silicon only) | $9.99/mo · $79.99/yr (or $5/$59.99 promo) | 20 min/week | Named "AI Modes" rewrite + speaker-separated meeting transcripts |
| aidictation.com | Mac/Win/iPhone/Android | Partial (auto-switches online/offline) | $8.49/mo | 2,000 words/mo | Mid-sentence language switching across 99+ languages |
| Voibe | Mac/Windows | Partial (Mac only; Windows = cloud) | $7.50/mo · $149 lifetime | 7-day trial only | Also runs the niche's biggest self-published competitor-review hub |
| Spokenly | Mac/iPhone/Win/Linux | Yes (on-device tier free forever) | $9.99/mo Pro (on-device free) | None on-device | Built-in MCP server for AI coding agents |
| BetterDictation | macOS (Apple Silicon only) | Partial (STT on-device, Pro cleanup cloud) | $39 lifetime + $2/mo Pro | Paid model, no ongoing free tier | Named Pro features: stammer correction, auto-formatting |
| Voice Type | macOS only | Yes, fully | $19.99 once | 7-day trial | User-selectable Whisper model size (speed/accuracy tradeoff exposed) |
| Voquill | Mac/Win/Linux/iOS | Yes (user's choice, local or BYOK cloud) | Free | None stated | Explicitly branded "open source alternative to WisprFlow" |
| Speakflow | Web | N/A (teleprompter, not dictation) | Free + paid tiers | N/A | Not a dictation app — name-collision risk only |
| Dictation Daddy | Mac/Win/Chrome/Android (iOS pending) | No (cloud) | $8–15/mo | 7-day trial | Medical-terminology transcription mode |
| Tuny | Unresolved | Unresolved | Unresolved | Unresolved | Not found in this crawl |
| Murmur | Mac/Windows | Yes, fully | €39.97 lifetime · €2.48/mo | 5 dictations/day | Budget lifetime price explicitly pitched vs. Superwhisper |
| Whisper Flow (Butterfly AI) | iPhone/Android/macOS | Unclear | Free | None stated | Free voice keyboard across all 3 platforms; name-collides with Wispr Flow |
| Talknotes | iOS/Android/web | No (cloud) | Freemium, tiers unclear | 2 hrs/note | "Choose a style" note transformation, not live dictation |
| Wave | macOS | User's choice | Unclear | Unclear | Explicit, first-class local-or-cloud toggle |
| Yap | macOS | Yes, fully | Free/open-source | None | Auto-fetches model, no manual download step |
| Qwen Scribe | Apple Silicon | Yes, fully | Unclear | Unclear | Uses Qwen models instead of Whisper |

---
## Patterns across newcomers

1. **"On-device" is frequently a half-truth.** At least three apps in this set (Voibe, BetterDictation, aidictation.com) run raw speech-to-text locally but silently route the AI cleanup/formatting/polish step — the part users actually value most — through a cloud API. Nasar Flow should audit and clearly disclose exactly which pipeline stages are on-device versus not, and lead with a genuinely complete offline claim across both mobile OSes as a differentiator, since none of these newcomers can make that claim on mobile.
2. **Platform coverage is usually partial and asymmetric.** Most of these apps are Mac-first (often Apple-Silicon-only), with iOS/Android as an afterthought or entirely absent (Dictation Daddy's iOS is still "coming soon"; Voice Type and BetterDictation are Mac-only). Nasar Flow's simultaneous iOS+Android coverage from day one is comparatively rare in this cohort.
3. **Free tiers are shrinking cloud-cost puppets, not real generosity.** Word/minute/day caps (2,000 words/mo, 30 min once, 5/day, 20 min/week) all trace back to the provider's per-request cloud STT bill. An on-device app like Nasar Flow has near-zero marginal cost per dictation, so it can credibly out-generous every cloud-dependent competitor's free tier without hurting margins.
4. **Lifetime pricing has become a standard tier**, clustering roughly €40–160 for on-device apps (Voice Type $19.99, Murmur €39.97, BetterDictation $39, Voibe $149) versus $250+ for cloud-dependent apps recovering ongoing API costs (Voicy $260). This gives Nasar Flow a pricing anchor if it ever introduces a paid tier: on-device apps are expected to price near the low end of that band.
5. **Naming collisions are rampant** (Whisper Flow vs. Wispr Flow, Voice Type vs. VoiceType/VoiceType AI, Speakflow the teleprompter vs. dictation apps) — the category has outgrown available brand-name space. Worth a deliberate check that "Nasar Flow" doesn't collide with an existing "Flow"-suffixed dictation product before further brand investment.
6. **Self-published competitor comparison content is now a default acquisition channel.** Utter, Spokenly, Voibe, and aidictation.com all run "X vs. Y" and "best alternatives to Z" content at scale, often reviewing each other. This is cheap to replicate and appears to be table stakes for SEO-driven discovery in this niche — worth a lightweight version for Nasar Flow once it has a public marketing site.
7. **Named, specific sub-features outsell generic "AI cleanup."** "Auto Edits," "Custom Replacements," "stammer correction," "AI Modes" — every app that names its cleanup steps distinctly appears more credible than one that says only "AI-powered." Nasar Flow's dialect-specific handling (once built from authentic native-speaker phrasing, per the project's own dialect-authenticity practice) should get equally specific, ownable feature names rather than a blanket "Singlish support" label.

---
*Crawl conducted 2026-09-09. Sources cited inline per section; where a claim could not be verified in a fetched page, it is marked "not found" or "unclear" rather than inferred.*
