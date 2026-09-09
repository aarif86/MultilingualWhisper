# Competitor knowledge base

Crawled 8–9 September 2026. Every per-app file follows `_TEMPLATE.md` (Facts → Activation → Insertion → Personalisation → Formatting → Commands → Languages → Privacy → Docs → Changelog → Engineering → Complaints → Best-practice takeaways → Ideas Nasar Flow should steal or beat). Conclusions are synthesised in [`../DICTATION-PLAYBOOK.md`](../DICTATION-PLAYBOOK.md); this folder is the evidence.

## Index

| File | Covers | Why it matters to Nasar Flow |
|---|---|---|
| `_nasar-flow-current-state.md` | iOS app, iOS keyboard/Flow session, Android IME, site promises, unmerged branches | The baseline every gap is measured against |
| `wispr-flow.md` | Category leader: hotkeys, Command Mode phrases, dictionary/snippet limits, tone presets, privacy incident, Trustpilot gap | The UX everyone copies; per-session language handling is its documented weakness |
| `willow-voice.md` | Background mic session mechanism, Dictation vs Scribe, "___ shortcut", edit-rate metric, offline-claim contradictions | Validates Nasar Flow's Flow-session design; shows the polish to add |
| `superwhisper.md` | Local model tiers, Modes, Vocabulary vs Replacements, S1 non-goals, llms.txt, iOS keyboard reliability | Closest on-device relative; language-switch limits of Parakeet/Nova |
| `macwhisper.md` | Dictation vs Global modes, App-Specific Prompts, Find/Replace, lifetime licence, changelog cadence | "Allow dictation everywhere" failure mode; no offline cleanup |
| `voiceink.md` | Verbatim enhancement system prompt, Word Replacements vs Vocabulary, trigger precedence, clipboard-paste fragility | The prompt template to adapt; media auto-pause |
| `aqua-voice.md` | Avalon model, Deep Context, Edit Mode, "Send It", status page, Privacy Mode default | Natural-language editing; screen-context bias |
| `typeless.md` | Speak-to-edit, Translate hotkey, dual-mode dictionary, over-broad permissions, cloud despite "on-device" copy | Permissions page as a trust weapon |
| `monologue.md` | Right-Shift mode picker, "Blazing Fast" raw mode, dictionary import from rivals, ≤3-language pre-select | Named raw mode; switching-cost killers |
| `talon-voice.md` | Command/dictation modes, `escape <text>`, whitelist inside dictation, `scratch that`, homophones UI | The command-boundary design to copy before shipping any command |
| `dragon.md` | Select-and-Say, formal correction menu, written-vs-spoken vocabulary, Auto-Texts, Dictation Box, Anywhere sunset | Correction UX; universal fallback pattern |
| `serenade.md` | In-file vocabulary weighting, ranked alternatives, recall@1/5/10, protocol for integrations | Context bias and alternatives UI |
| `open-source-clones.md` | Handy, Ito (deprecated, cloud despite "local"), Whisper Writer, Buzz | Injection method lessons; four recording modes; backend abstraction |
| `apple-dictation-voice-control.md` | Full iOS/macOS dictation command list, Voice Control modes, SpeechAnalyzer, bilingual limits, `hasDictationKey` | The muscle memory to match |
| `windows-voice-access.md` | Voice Typing vs Voice Access, Fluid Dictation (on-device Phi Silica cleanup), "Correct <word>" loop, full command list | The on-device cleanup precedent to copy and beat |
| `google-gboard-android.md` | Gboard voice commands, Pixel-gated advanced typing and natural-language rewrite, offline languages, Samsung brief | Android baseline users compare against |
| `mobile-keyboards.md` | iOS keyboard flows of Wispr/Willow/Superwhisper/Aqua/Typeless; mic-ban workaround comparison table | Direct prior art for `NasarFlowKeyboard` |
| `android-ime-voice-input.md` | FUTO Voice Input (ACFT, permission pattern, compatibility), Transcribro, Sayboard, IME vs AccessibilityService | Direct prior art for `NasarFlowAndroid` |
| `voice-note-apps.md` | Voicenotes, AudioPen, Whisper Memos, Just Press Record, Oasis, Cleft | Rewrite styles, intensity sliders, lost-recording lessons |
| `whispering.md` | Whispering / Epicenter: verbatim Polish system prompt ("You are a text filter, not an assistant"), `<known_terms>` dictionary block, provider list with pricing, HN local-first pushback, AGPL relicense and v8 fold-in | Prompt wording to adapt; the "local-first" credibility bar |
| `newcomers.md` | Voicy, Utter, aidictation, Voibe, Spokenly, BetterDictation, Voice Type, Voquill, Dictation Daddy, Murmur, Whisper Flow (not Wispr), Talknotes, Wave, Yap, Qwen Scribe, LumeVoice, DictaFlow, DictaType; comparison table; 7 patterns | "On-device" half-truths; lifetime price band; name collisions |
| `engine-best-practices.md` | Deepgram, AssemblyAI, OpenAI, whisper.cpp params, Azure/Google/Speechmatics, Picovoice, Parakeet, Moonshine, SpeechAnalyzer, Kyutai, sherpa-onnx, MERaLiON, Mesolitica, IMDA NSC, SEAME, ITN libraries | 15 concrete whisper.cpp/pipeline recommendations |
| `user-voice.md` | Top 20 complaints, 15 praises, switching triggers, accent/code-switch discourse, pricing and privacy sentiment, mobile friction | What users actually punish and reward |
| `pricing-and-positioning.md` | Pricing table for 17 products; seven positioning white spaces | The lane |

## Maintenance

- Re-crawl quarterly; changelog URLs are listed in each file's Facts section.
- When a competitor ships something new, add it to the relevant file's "Changelog & velocity" section and, if it changes a conclusion, to the playbook.
- Reddit was bot-blocked during the initial crawl; `user-voice.md` §Method note lists the follow-up.
