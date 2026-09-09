# Voice-note "talk then AI-clean" apps

> Voicenotes, AudioPen, Whisper Memos, Just Press Record, Oasis, Cleft. These are not system-wide dictation keyboards; they are capture-first note apps whose value is the *rewrite/organize* layer after transcription. They are the closest prior art for Nasar Flow's in-app Transcribe/History tabs and for any future "style"/rewrite feature.

## 1. Voicenotes (voicenotes.com)

- **Platforms:** macOS, iOS, Windows, Android, Web, Apple Watch. https://voicenotes.com/
- **Capture:** single "hit record"; works for in-person and online meetings "without a bot"; you can jot comments while recording. Web supports offline recording, auto-transcribed on reconnect (Aug 2024).
- **AI cleanup ("Create / AI Creations"):** 8 built-in preset prompts + a custom-prompt box, with **Custom** and **Saved** tabs to manage reusable prompts. Named creations: Meeting Report, Cleanup, Translate. "Extract tasks, rewrite in your style, or generate a blog post from a ramble." https://help.voicenotes.com/en/articles/9220745-release-notes
- **Summaries:** auto summary + action items + next steps after meetings; "Just Ask. AI Remembers" chat across all notes.
- **Organization:** auto-titling, auto-tagging (Feb 2025), tag management, multi-word tags, Team Channels (Mar 2025), Calendar View replacing "Streaks UI" (Mar 2025).
- **Long recordings:** cap raised 40 → 90 min (Feb 2025); longer sessions split into **subnotes**; Meeting mode adds timestamps (Nov 2024).
- **Pricing (2026):** Basic free — unlimited recordings but **100 weekly transcription minutes**, 30-day history. Pro **$9/user/mo** (App Store shows $14.99/mo, $89.99–99.99/yr) — unlimited minutes, live transcription, unlimited history, imports. Enterprise **$24/user/mo** (SSO/SCIM, consent management). Never trains on user data. No lifetime. https://voicenotes.com/pricing
- **Integrations:** Zoom/Teams/Meet/Webex/Slack, Chrome extension, Zapier, webhooks, Readwise, Todoist, Things3, WhatsApp, public **MCP server** (Mar 2026).
- **Onboarding:** redesigned 5-step flow "reducing friction and improving activation".
- **Complaints:** crashes; missing/cut-off transcriptions; invented to-dos; **failed uploads = lost notes** (device sleeps mid-recording); no bulk export; billing after cancellation; recording silently stopping. Praise: developer ships requested features "within days". https://ca.trustpilot.com/review/voicenotes.com

## 2. AudioPen (audiopen.ai)

- **Capture:** "Ramble freely", minimal chrome; Apple Watch. https://www.audiopen.ai/
- **Styles:** gallery at audiopen.ai/styles — presets include bullet list, casual memo, technical doc, email, Twitter thread, action items, Simple & clear, Academic, Business memo, Shakespeare; fully custom styles that mimic your own voice. (Triangulated from third-party summaries; primary page had no extractable body.)
- **Rewrite-intensity slider:** **Low** ("keep it close to your exact words") / **Medium** / **High** ("let AudioPen polish everything"). Same three-notch pattern as Wispr Flow's Light/Medium/High.
- **Templates:** "Summary" is really a full restructure into prose in the chosen style. Prime-only **SuperSummaries** synthesize across multiple notes. **Restyle** re-runs a past note through a different style. Upload audio or paste text.
- **Sync:** iOS, Android, Chrome, Mac, Windows.
- **Long recordings:** **15 min per recording** cap; reviewers ask for longer/unedited recordings.
- **Pricing:** free tier usage-limited; Prime **$33/3mo, $99/yr, $159/2yr** (old "$29 one-time" figure is stale). 30-day refund on 2-yr plan. https://aiforbusinessautomation.com/tools/audiopen-review/
- **Complaints:** price; wants custom prompts; **no background recording on iOS**; login issues; audio not picked up when walking; rewrite **too aggressive** ("compensating for imperfect capture rather than preserving what was said"). https://www.producthunt.com/products/audiopen/reviews

## 3. Whisper Memos (whispermemos.com)

- **Capture:** lock-screen widget, Apple Watch complication / Action Button, Siri/Shortcuts, audio import (MP3/M4A/WAV/AAC/FLAC ≤100MB). Default output is **emailing the transcript to yourself**. "Private mode" = transcripts not stored on their servers (still cloud-transcribed). https://whispermemos.com/
- **Models:** user picks backend — OpenAI Whisper (~90%), ElevenLabs Scribe (96.7%), Cohere Transcribe (94.6%) — plus default AI summary and custom-prompt summaries.
- **Organization:** no folders/tags; **"Agents"** = named automations routing memos to destinations (tasks, journaling, team); Zapier → Notion/Todoist/Evernote.
- **Long recordings:** up to **90 min** (was 15 — the old cap drove complaints). Offline recording, deferred upload.
- **Pricing:** **$69.99/yr** (~$5.83/mo), positioned as undercutting Otter (~$100/yr) and AudioPen (~$99/yr). https://findmyaitool.com/tool/whisper-memos
- **Sentiment:** praised for accuracy above native iOS dictation, cost, Watch integration, "thoughtful single-purpose design", responsive dev. Complaints: subscription for occasional use, price hikes, old 15-min cap, **privacy tradeoff** (audio goes to third-party APIs). https://whispermemos.com/reviews

## 4. Just Press Record (Open Planet Software)

- **UX:** recorder-first. Widget "record button everywhere"; Watch one-tap + complication + Siri; pause via swipe; unlimited length; background recording; URL scheme trigger. https://www.openplanetsoftware.com/just-press-record/
- **Transcription:** system on-device speech-to-text, 30+ languages independent of system language; editable, searchable; **no AI rewrite layer at all**.
- **Export:** M4A/WAV/AIF up to 96kHz/24-bit; iCloud Drive sync visible in Files.
- **Pricing:** **one-time $4.99–6.99**, no subscription. https://apps.apple.com/us/app/just-press-record/id1033342465
- **Sentiment:** praise for buy-once, Watch-first, stereo, near-complete VoiceOver support. Complaints: transcription suddenly stopping entirely; Watch playback muted; iCloud sync delays; missing languages (e.g. Filipino); older reviews cite 75–80% accuracy dropping to ~50%.

## 5. Oasis (theoasis.com)

- **Flow:** record/upload → on-device transcription → review/edit raw transcript (relisten alongside) → run one or more **AI Rewrite templates** → edit output → **regenerate** → run further rewrites with other templates (language switching supported here) → favorites/history/copy/export. https://help.theoasis.com/en/articles/8500162-refining-your-content
- **Templates:** "20+ AI rewrite templates" + custom: professional email, blog post, college essay, LinkedIn post, text message, outline, TikTok script, pop song, Summary. No public full list.
- **Sharing:** one-tap to Gmail, iMessage, WhatsApp, Notion, Slack, Teams, Apple Notes. Organization is History + Favorites, no folders/tags surfaced.
- **Pricing:** Free; Basic **$4.99/mo** ($4.17 annual) 3,000 credits; Pro **$14.99/mo** ($12.50 annual) 30,000 credits; a one-time 6,000-credit pack $59.99; Enterprise custom. https://www.gettingstuffdone.ai/tool/oasis/
- **Research gap:** App Store listing (id1668222944) returned 404; searches conflate with unrelated "Oasis" apps. Complaint data unverified.

## 6. Cleft (cleftnotes.com) — closest technical cousin (on-device Whisper)

- **Capture:** one-tap from anywhere; **style picker BEFORE recording** (Watch: pick style with Digital Crown, record, sync back; CarPlay v1.14+ same flow); **resume a recording later** ("Close mid-recording and return later. Cleft keeps your place"). Transcription **on-device with Whisper**. https://cleftnotes.com/product
- **Styles:** built-in **Structured**, **Structured Prose**, **Clean Transcript**; auto title; **Custom Styles** (Plus) saved to the "recording dial"; regenerate when format changes.
- **Organization:** tags by project/topic, full-text search + Spotlight, **Append** (Plus) adds a new recording onto an existing note, in-app Markdown editor, stable per-note metadata (IDs, timestamps, source, tags).
- **Sync:** notes, style, theme, rules and export choices follow Apple devices; **local sync** auto-exports Markdown (+ optional audio) to a folder (Plus). Apple-only.
- **Long recordings:** Free 5 min; Plus 30 min. Hard caps, no chunking.
- **Pricing:** Basic free; **Plus $6.99/mo or $39.99/yr**; adds 30-min, 500-char custom AI instructions, Append, custom styles, auto-copy, attachments, Notion/Zapier, password-protected share links, Family Sharing, TestFlight early access. https://cleftnotes.com/pricing
- **Onboarding:** learn.cleftnotes.com docs hub, "Book a call" for personal setup, in-app recipe guides. https://learn.cleftnotes.com/user-guides/faq
- **Sentiment:** very strong with ADHD/neurodivergent users ("makes sense of the stream of thoughts"); one documented loss of recordings due to manual-sync requirement. https://thesweetsetup.com/cleft-notes-is-the-thinking-companion-i-didnt-know-i-needed/

## Cross-cutting takeaways

1. **Rewrite intensity is a universal control** — AudioPen Low/Medium/High mirrors Wispr Flow Light/Medium/High. Users complain when rewrite is "too aggressive"; always keep the raw transcript one tap away (Oasis and Cleft both keep raw + polished).
2. **Choose the style before you speak** (Cleft) is a cheaper, lower-latency UX than choosing after: you can prime the prompt and skip a second pass.
3. **Three built-in styles is enough** (Cleft: Structured / Structured Prose / Clean Transcript); custom styles are a paid upsell everywhere.
4. **Lost recordings are the #1 trust-killer** across Voicenotes, Cleft, AudioPen — audio must be persisted to disk *before* transcription starts, and uploads/transcriptions must be retryable. Nasar Flow already keeps audio local; make the "never lose a recording" guarantee explicit in UI.
5. **Recording caps are a pricing lever** (5/15/30/90 min tiers) and a recurring complaint. An offline app has no per-minute cost, so "unlimited length" is a free differentiator.
6. **Resume-later and Append** (Cleft) are cheap features with outsized love from note-takers.
7. **Automations over folders** (Whisper Memos "Agents", Voicenotes MCP/Zapier) — routing output to a destination is what users actually want from organization.
8. **On-device is rare in this category** (only Cleft); "private mode" claims that still hit cloud APIs (Whisper Memos) are a weaker claim Nasar Flow can counter-position against.
9. **One-time pricing still sells** (Just Press Record) — the anti-subscription segment is real.
10. **Buy-once + Watch/widget/Shortcut entry points** are table stakes for capture apps; Nasar Flow has none of widget / Shortcuts / Action Button / Watch yet.

## Ideas Nasar Flow should steal or beat

1. [steal] Rewrite-intensity slider with raw transcript always retrievable.
2. [steal] Pick-style-before-recording on the keyboard mic button (long-press → style).
3. [steal] Append-to-existing-transcript and resume-later in History.
4. [beat] "Unlimited length, never uploaded" as a headline — nobody offline offers unlimited-length with AI cleanup on phone.
5. [steal] Shortcuts / widget / Action Button / Watch capture entry points.
6. [beat] Cleft's on-device Whisper is English-centric; Nasar Flow's dialect models + styles in Malay/Arabic output is uncontested.
