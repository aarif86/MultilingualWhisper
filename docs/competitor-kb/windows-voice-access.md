# Windows Voice Typing / Voice Access

> One-line: Microsoft, built into Windows 11/10; OS-native dictation (Voice Typing, Win+H) and a full hands-free PC-control layer (Voice Access) for people who want or need to operate their PC by voice.

## Facts
- **Maker / founded / funding:** Microsoft. Voice Typing (formerly "Windows Speech Recognition" dictation flow) has existed in some form since Windows 10; the modern Azure-backed Voice Typing shipped with Windows 11. Voice Access is a Windows 11 22H2+ accessibility feature (2022) that formally replaced the legacy "Windows Speech Recognition" (WSR) full-PC-control feature starting September 2024 on 22H2+.
- **Platforms:** Windows 11 and Windows 10 (Voice Typing only); Voice Access requires Windows 11 version 22H2 or later. No macOS/iOS/Android/Linux/browser equivalent from Microsoft.
- **Pricing:** Free, built into the OS. No tiers, no per-word caps.
- **Engine:** Voice Typing = **online/cloud** speech recognition powered by Azure Speech services (requires internet to dictate). Voice Access = **on-device** speech recognition, works with no internet connection (only needs internet once, to download the language model). "Fluid dictation" (Copilot+ PCs only, in both Voice Typing and Voice Access) is on-device LLM post-processing using the on-device "Phi Silica" small language model (SLM) to auto-correct grammar, punctuation, and filler words as you speak.
- **Languages:** Voice Typing: 50+ languages/locales (see list below). Voice Access: a much smaller set — English (US, UK, India, New Zealand, Canada, Australia), Spanish (Spain, Mexico), German (Germany), French (France, Canada), Chinese (Simplified China, Traditional Taiwan), Japanese, Italian. Fluid Dictation (both features): English locales only, Copilot+ PCs only. No stated code-switching/mixed-language support in either feature's docs — code-switching is not a mentioned use case.
- **Docs / KB / blog / changelog URLs (all crawled):**
  - https://support.microsoft.com/en-us/windows/use-voice-typing-to-talk-instead-of-type-on-your-pc-fec94565-c4bd-329d-e59a-af033fa5689f
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/use-voice-access-to-control-your-pc-author-text-with-your-voice
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/get-started-with-voice-access
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/set-up-voice-access
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/voice-access-command-list
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/dictate-text-with-voice
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/correct-text-with-voice
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/select-text-with-voice
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/edit-text-with-voice
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/navigate-text-with-voice
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/use-voice-to-interact-with-items-on-the-screen
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/use-the-mouse-with-voice
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/use-the-keyboard-with-voice
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/use-voice-to-work-with-windows-and-apps
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/use-voice-to-create-voice-access-shortcuts
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/fluid-dictation
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/history-of-voice-access-updates
  - https://support.microsoft.com/en-us/accessibility/windows/voice-access/windows-speech-recognition-commands
  (18 distinct pages crawled.)

## Activation & capture UX
**Voice Typing (Win+H):**
- Default hotkey: **Windows key + H**, from any text box, on a hardware keyboard. On a touch device, tap the microphone button on the touch keyboard.
- Alternate keyboard-only path: **Windows key + Alt + H** navigates the voice typing menu with the keyboard (for users who can't use a mouse).
- It is a **toggle**, not push-to-talk: once launched it starts listening automatically; wait for the "Listening…" alert before speaking. Say "Stop listening" (or other stop phrases) or click the mic button to end.
- Echo cancellation: Voice Typing automatically suppresses audio coming from the PC's own speakers (e.g. Narrator, app playback) so it only picks up the user's voice.
- Feedback while recording: a small flyout/menu appears near the text cursor with a mic icon and a "Listening…" status; a settings gear icon on that flyout exposes auto-punctuation, profanity filter, mic selection, and "wait time before acting."
- No mobile app (Windows-only, hardware keyboard or touch keyboard on 2-in-1s/tablets).

**Voice Access:**
- Launch via Settings > Accessibility > Speech > toggle "Voice access" on, or via Windows Search ("voice access"). Can be configured to auto-start before or after sign-in.
- After launch, a **persistent UI bar is docked at the top of the screen** at all times — this is the main recording/status indicator (not a transient overlay like Voice Typing's).
- Three explicit **microphone states**, each with a voice command, keyboard shortcut, and mouse click:
  - **Sleep**: ignores everything except the wake phrase. Wake with "Voice access wake up" / "Unmute", or **Alt+Shift+B**, or left-click the mic button.
  - **Listening**: actively listens and executes recognized commands, or shows an error if not recognized. Put to sleep with "Voice access sleep" / "Mute", or Alt+Shift+B, or left-click.
  - **Microphone off**: fully off, no listening at all. Turn off with "Turn off microphone" or Alt+Shift+C (long press) from listening state; turn back on with Alt+Shift+C or a left-click (no voice command available to turn mic back on from the off state).
- Visual feedback on the bar: real-time transcription of what's heard (left side), command-execution status (center, while processing), and command-execution feedback (success or error) after the command runs.
- This is effectively a **toggle + wake-word system**, not push-to-talk: "Voice access wake up" is the closest thing to a wake word.

## Text insertion
- Voice Typing: inserts directly at the text cursor in whatever text box has focus; relies on the standard Windows text-input pipeline (not a separate keyboard-extension architecture — no iOS/Android equivalent).
- Voice Access: same direct-cursor insertion model, but layered on top of full UI automation — Voice Access can move focus to any control (text box, button, menu) by name or by number overlay before dictating/clicking, using what appears to be UIA (UI Automation) under the hood to identify on-screen elements, click them, and target text fields. If a text box has no visible label, "Show numbers" tags it with a number overlay you can click/say.
- No stated fallback behavior for "unsupported" apps in the docs (unlike some third-party dictation tools that call out broken apps); Voice Access explicitly supports partial name matches for UI elements (e.g. "Click privacy" matches "Privacy & security"), and can spell out special characters/numbers embedded in item names (e.g. "Click dial hyphen up" or "Click seven" for a button named "7").

## Accuracy & personalization
- **Add to vocabulary**: Voice Access lets users add custom/difficult-to-pronounce words to a personal dictionary via Settings > Add to vocabulary, via the "Add to Vocabulary" voice command, or automatically after spelling a word with "Spell that" or correcting one with "Correct that." Available in all supported Voice Access languages. This biases recognition toward the user's specific vocabulary.
- **Correction flow** (Voice Access): say "Correct <text>" or "Correct that" (on selected/last-dictated text) → opens a correction window listing numbered alternative-text suggestions → say "Click <number>" to swap in that suggestion, or say "Spell that" (or click the numbered "Spell that" option) to manually spell the correct word letter-by-letter. Microsoft explicitly recommends correcting **one word at a time** — correcting multi-word spans yields worse suggestions.
- **Spell out** command: dictate letter-by-letter for non-standard words ("Spell out" to start spelling; "Spell that" to spell out already-selected/dictated text).
- No per-app context, no contacts-based name recognition, no screen-context features mentioned in either feature's docs.
- Voice Typing has a "wait time before acting" setting (delay before a command executes) to accommodate different speech speeds/patterns — same setting name exists in Voice Access.

## Formatting & AI cleanup
- **Fluid dictation** (Copilot+ PCs only, English locales only, both in Voice Typing and Voice Access): on-device SLM ("Phi Silica") automatically corrects grammar, punctuation, and filler words live as you speak, "reducing the need for manual editing." Enabled by default; toggle from Voice typing/Voice access settings or by voice command ("turn on/off fluid dictation"). Automatically disabled on secure fields (passwords/PINs). To undo a correction: say "Revert," "Undo that," or press Ctrl+Z, and the original (uncorrected) dictation is restored. Model download happens automatically in the background on first launch (visible as a dimmed Fluid dictation setting until the SLM finishes downloading, tracked via Settings > Windows Update).
- No stated tone/style modes (email vs. chat vs. code) — this is a flat dictation/correction model, not a rewrite/AI-prompt system.
- Explicit format-by-voice commands exist in Voice Access (see Full command list) for bold/italic/underline/capitalize/uppercase/lowercase on specific text, ranges, or "that" (last dictated/selected).

## Voice commands
See the dedicated **Full command list** section below for the exhaustive, verbatim command tables. Highlights:
- Voice Typing: "Stop listening" family, "Delete that"/"Erase that"/"Scratch that", "Select that", "Press Enter/Backspace/Tab/Space", "Undo that"/"Revert", plus a full punctuation-name table ("comma", "period", "new line", etc.).
- Voice Access: an enormous command surface — app/window control, mouse/keyboard emulation, number-overlay and grid-overlay clicking, text selection/navigation/editing/formatting by word/line/paragraph/character count, and correction commands ("Correct that", "Correct <text>").

## Languages & multilingual
- Voice Typing supports 50+ languages/locales, switchable per-session via the taskbar language switcher or Win+Spacebar; a different voice-typing language than the Windows UI language can be installed and used.
- Voice Access supports a much smaller, fixed set: English (US/UK/India/New Zealand/Canada/Australia), Spanish (Spain/Mexico), German (Germany), French (France/Canada), Chinese (Simplified China/Traditional Taiwan), Japanese, Italian. Japanese was added as a documented update (dated update entry, see changelog) — this is one of the more recently-added languages.
- **No auto-detection or mixed-language/code-switching support is mentioned anywhere** in either feature's documentation — each session runs against one selected recognition language/locale. This is a clear structural gap Nasar Flow's Singlish/Malay/Arabic code-switching design does not have to fight against, since Microsoft doesn't attempt it at all.
- Fluid Dictation (the LLM cleanup layer) is English-only regardless of base recognition language.

## Privacy & data
- Voice Typing: explicitly **online/cloud** (Azure Speech services) — no on-device/offline mode documented for Voice Typing dictation itself (only Fluid Dictation's cleanup layer is on-device, and only on Copilot+ PCs).
- Voice Access: explicitly **on-device** speech recognition; works fully offline after the one-time language-model download (which requires internet). Positioned as an accessibility feature, so privacy-by-design is emphasized (e.g., Fluid Dictation auto-disables on password/PIN fields).
- No SOC2/HIPAA/enterprise retention claims in either consumer-facing article set; a link to Microsoft's Privacy Statement is provided from within the Voice Access setup flow.

## Onboarding & docs
- Voice Access has a dedicated **first-run interactive guide** ("voice access guide") — a two-pane practice environment (instructions left, live practice area right) that opens automatically on first setup and can be reopened anytime by voice ("Open voice access guide") or from the Help menu.
- Setup flow: Settings > Accessibility > Speech > toggle on, or search "voice access" in Windows Search; a welcome/consent screen explains microphone/speech usage before the user proceeds; language selection happens before the on-device language model downloads (needs internet for this step only).
- Docs are organized as a flat set of task-focused accessibility articles nested under `.../accessibility/windows/voice-access/...` (Get started, Set up, Command list, Dictate text, Correct text, Select text, Edit text, Navigate text, Use voice to work with windows and apps, Use the mouse with voice, Use the keyboard with voice, Use voice to interact with items on the screen, Use voice to create voice access shortcuts, Fluid dictation, multi-display setup, sign-in setup, History of voice access updates), each cross-linking to the others via a consistent "See also" block and a consistent "This article is for people who want to control their PC and author text using their voice with Windows" framing sentence — clearly an accessibility-first documentation set, not a general productivity pitch.
- Every article surfaces an inline "Get help with Copilot" prompt box with pre-seeded example questions (e.g. "What are the steps to turn fluid dictation on or off?") — Microsoft is routing support questions into Copilot chat directly from the doc page.

## Changelog & velocity
Voice Access maintains a single **"History of voice access updates"** page — an undated, most-recent-first feature list (no explicit dates in the article itself). Notable entries, newest-first as documented:
1. **Introducing fluid dictation in voice access** — on-device SLM grammar/punctuation/filler cleanup, Copilot+ PCs, English locales, enabled by default.
2. **"Wait time before acting" setting** — configurable delay before a voice command executes, to fit different speech speeds.
3. **Voice access in Japanese** — added as a supported language.
4. **Extended support for flexible and natural commanding** (Copilot+ PCs) — the engine now understands multiple natural phrasings of the same command intent (e.g. "Can you open Edge application?", "Switch to Microsoft Edge", "Please open the Edge browser" all resolve to opening Edge) instead of requiring exact command syntax.
5. **Add custom words to the dictionary** — "Add to vocabulary" feature, reachable from settings, from the spelling/correction flow, or by direct voice command.
6. **In-app "What's New" announcement** — a highlight window appears after a major update, reachable later from the settings menu.
7. **Improvements to the Spellings & Corrections experience** — better/more correction suggestions (article was truncated by our fetch here; not read in full).
- On the Voice Typing side, Microsoft states Voice Access **replaced Windows Speech Recognition (WSR)** as the full-PC-control tool on Windows 11 22H2+ starting **September 2024**; WSR remains available only on older Windows versions.

## Blog / engineering insights
- No dedicated engineering blog post was found in this crawl about latency, model architecture, or evaluation methodology for either feature. The only architecture detail Microsoft discloses in support docs (not a blog) is that Fluid Dictation runs on the on-device **"Phi Silica"** small language model, downloaded and managed like a Windows Update component, and that Voice Typing (base recognition) runs on **Azure Speech services** in the cloud while Voice Access (base recognition) runs fully on-device.

## User complaints (reviews, Reddit, HN, App Store)
- Not collected in this crawl — task scope was limited to support.microsoft.com documentation pages (12+ pages fetched, all from support.microsoft.com). No Reddit/HN/App Store research was performed for this competitor file.

## Best-practice takeaways
1. **Enumerate every command surface in one canonical, versioned reference page** — Voice Access's single "Voice access command list" article is exhaustive, grouped by task category (manage mic, apps, controls, overlays, mouse/keyboard, dictate, select, edit, format, navigate, punctuation, symbols), and every other article links back to it. Nasar Flow should maintain one equivalent canonical command reference rather than scattering commands across screens.
2. **Give every command 2–4 synonym phrasings**, not one fixed phrase — e.g. stopping dictation accepts "Stop listening," "Stop dictation," "Pause voice typing," "Stop voice mode," etc. This tolerates natural variation instead of forcing users to memorize exact wording.
3. **Ship a numbered-correction-suggestion UI**: "Correct that" → numbered list of alternatives → "Click <number>" to accept, or "Spell that" to manually spell it. This is a clean, low-friction voice-native correction loop worth copying almost verbatim.
4. **On-device LLM cleanup should be reversible with a single spoken word** — "Revert" / "Undo that" instantly restores the pre-cleanup version of Fluid Dictation's correction. Users trust an AI cleanup layer much more when the undo path is one phrase away, not a settings toggle.
5. **Explicit mode-switching commands** ("Commands mode," "Dictation mode," "Default mode") let power users lock out accidental dictation-vs-command ambiguity — useful for any tool that mixes free dictation with command phrases in the same session.
6. **A wake/sleep/off three-state microphone model** (not just on/off) gives users a "paused but ready" state distinct from "fully off," reducible to one phrase ("Voice access wake up") or one shortcut.
7. **Auto-disable AI/recording features on secure fields** (passwords, PINs) by default — a privacy default Nasar Flow should match without asking.
8. **Undated, reverse-chronological single-page changelog** keeps discovery simple for users, even without a shipped-date; but Nasar Flow should still date its own entries — the absence of dates in Microsoft's changelog is a minor weakness worth improving on, not copying.

## Ideas Nasar Flow should steal or beat
1. [steal] Numbered correction-suggestion list triggered by "Correct that" / "Correct <word>," with "Spell that" as a fallback to manually spell a stubborn word.
2. [steal] Synonym-tolerant command phrasing (multiple accepted phrasings per intent) rather than one rigid trigger phrase per action.
3. [steal] One-word undo for AI cleanup ("Revert"/"Undo that") specifically scoped to the last AI correction, separate from general undo.
4. [beat] Microsoft's Fluid Dictation and Voice Access's multilingual support are **English-only / fixed-locale-only** with zero code-switching or auto-detected mixed-language support — Nasar Flow's whole reason to exist (Singlish/Malay/Arabic code-switching in one utterance) is a gap Microsoft has not even attempted to close. This is the clearest differentiation point to lead marketing with.
5. [beat] Voice Typing requires the cloud (Azure) for its base recognition, and only Fluid Dictation's cleanup layer is on-device, and only on Copilot+ hardware. Nasar Flow's whisper.cpp offline-first architecture on ordinary (non-Copilot+) hardware is strictly better on the privacy/offline axis for the base dictation itself, not just a cleanup layer.
6. [beat] Voice Access's "Add to vocabulary" is a manual, deliberate action (settings menu or explicit command) — Nasar Flow could beat this with **passive auto-learning from corrections** (already noted as a template category) so the vocabulary improves without the user remembering to invoke a feature.
7. [beat] Microsoft ships one settings toggle for "wait time before acting" as the main personalization lever for speech-pattern variation; Nasar Flow can beat this with actual per-user acoustic/vocabulary adaptation rather than a single timing knob.
8. [steal-but-improve] The three-state mic model (sleep/listening/off) plus a spoken wake phrase is a good UX skeleton for a hands-free toggle mode — Nasar Flow could adopt an equivalent for a future hands-free companion mode, while keeping push-to-talk as the primary mobile-keyboard-extension pattern (which Microsoft's OS-level model doesn't need to solve, but Nasar Flow's keyboard-extension context does).

## Full command list

### Voice Typing commands (Win+H)
Source: https://support.microsoft.com/en-us/windows/use-voice-typing-to-talk-instead-of-type-on-your-pc-fec94565-c4bd-329d-e59a-af033fa5689f — English (United States) tables, verbatim.

**Voice typing commands (What you can say):**
| To do this | What you can say |
|---|---|
| Stop or pause voice typing | "Pause voice typing", "Pause dictation", "Stop voice typing", "Stop dictation", "Stop listening", "Stop dictating", "Stop voice mode", "Pause voice mode" |
| Delete last spoken word or phrase | "Delete that", "Erase that", "Scratch that" |
| Select last spoken word or phrase | "Select that" |
| Press Enter | "Press Enter" |
| Press Backspace | "Backspace", "Press Backspace" |
| Press Tab | "Tab", "Press Tab" |
| Press Space | "Insert Space", "Press Space" |
| Undo previous change | "Undo that", "Revert" |

**Punctuation commands (To Insert this / Say this)** — English table:
| To insert | Say this |
|---|---|
| ‘ (begin/open single quote) | "begin/open single quote" |
| ’ (end/close single quote) | "end/close single quote" |
| - | "Hyphen", "minus sign", "n-dash" |
| – | "m-dash" |
| ! | "exclamation mark/point" |
| # | "number/pound sign" |
| $ | "dollar sign" |
| % | "Percent sign" |
| & | "ampersand", "and sign" |
| ( | "left/open parentheses" |
| ) | "right/close parentheses" |
| * | "asterisk" |
| , | "comma" |
| . | "period, full stop" |
| … | "ellipsis, dot dot dot" |
| / | "forward slash" |
| : | "colon" |
| :( | "frowny face" |
| :) | "smiley face" |
| ; | "semicolon" |
| ;) | "winky face" |
| ? | "question mark" |
| @ | "at sign, at mention" |
| [ | "left/open (square) bracket" |
| \ | "backslash" |
| ] | "right/close (square) bracket" |
| ^ | "caret symbol" |
| _ | "underscore" |
| \` | "backquote, backtick" |
| { | "left/open (curly) brace" |
| \| | "vertical bar sign/character, pipe character" |
| } | "right/close (curly) brace" |
| ~ | "tilde symbol" |
| " (open) | "open quotes" |
| " (close) | "close quotes" |
| £ | "pound sterling sign" |
| ¥ | "yen sign" |
| € | "euro sign" |
| + | "plus sign" |
| < | "less than sign, left/open angle bracket" |
| <3 | "heart emoji" |
| = | "equal sign" |
| > | "greater than sign, right/close angle bracket" |
| ± | "plus or minus sign" |
| × | "multiplication sign" |
| ÷ | "division sign" |
| § | "section sign" |
| © | "copyright sign/mark" |
| ® | "registered sign" |
| ° | "degree symbol/sign" |
| ¶ | "paragraph sign/mark" |
| (new line) | "new line", "new/next line", "new paragraph" (appears twice in source table) |
| 's | "apostrophe-s" |

### Voice Access commands (Windows 11 accessibility feature)
Source (master list): https://support.microsoft.com/en-us/accessibility/windows/voice-access/voice-access-command-list — verbatim, grouped exactly as Microsoft documents it.

**Manage voice access and microphone**
| To do this | Say this |
|---|---|
| Get voice access to listen to you | "Voice access wake up", "Unmute" |
| Put voice access to sleep | "Voice access sleep", "Mute" |
| Turn off the voice access microphone | "Turn off microphone" |
| Close voice access | "Turn off voice access", "Stop voice access", "Close voice access", "Exit voice access", "Quit voice access" |
| Find out what command to use | "What can I say", "Show all commands", "Show command list", "Show commands" |
| Access voice access settings menu | "Open voice access settings" |
| Access voice access help menu | "Open voice access help" |
| Access the voice access tutorial | "Open voice access guide" |
| Switch to commands only mode | "Commands mode", "Switch to command mode" |
| Switch to dictation only mode | "Dictation mode", "Switch to dictation mode" |
| Switch to default mode (command and dictation) | "Default mode", "Switch to default mode" |

**Interact with apps**
| To do this | Say this |
|---|---|
| Open a new app | "Open <app name>", "Start <app name>", "Show <app name>" |
| Close an open app | "Close <app name>", "Close window", "Exit <app name>", "Quit <app name>" |
| Switch to an existing app | "Switch to <app name>", "Go to <app name>" |
| Minimize a window | "Minimize window", "Minimize <app name>" |
| Maximize a window | "Maximize window", "Maximize <app name>" |
| Restore a window | "Restore window", "Restore <app name>" |
| Open task switcher | "Show task switcher", "List all windows", "Show all windows" |
| Go to desktop | "Go to desktop", "Go home", "Minimize all windows" |
| Search on the browser (search engine = Bing/Google/YouTube) | "Search on <search engine> for <x>" |
| Snap window to a direction (left/right/top-left/top-right/bottom-left/bottom-right) | "Snap window to <direction>", "Snap the window to <direction>" |
| Search for a file or app | "Search <Entity>", "Search Windows for <Entity>", "Search for <Entity>" |

**Interact with controls**
| To do this | Say this |
|---|---|
| Select an item | "Click <item name>", "Tap <item name>" |
| Double-click an item | "Double-click <item name>", "Mouse double-click" |
| Put focus on an item | "Move to <item name>", "Focus on <item name>" |
| Expand a list | "Expand <item name>" |
| Toggle between states | "Toggle <item name>", "Flip <item name>" |
| Scroll in a specific direction | "Scroll <direction>" |
| Start scrolling in a specific direction | "Start scrolling <direction>" |
| Stop scrolling | "Stop scrolling", "Stop" |
| Move a slider a set distance in a direction | "Move slider <direction> <value> times" |

**Interact with overlays** (number grid / mouse grid)
| To do this | Say this |
|---|---|
| Show number overlays on your screen | "Show numbers", "Show numbers everywhere" |
| Show number overlays on the current app | "Show numbers here" |
| Show number overlays on a specific app/window | "Show numbers on <app name>" |
| Show numbers over the taskbar | "Show numbers on taskbar" |
| Remove number overlays | "Hide numbers", "Cancel" |
| Select a numbered item | "Click <number>", "<number>" |
| Show grid overlay on your screen | "Show grid", "Show grid everywhere", "Show window grid" |
| Show grid overlay on current window | "Show grid here" |
| Remove grid overlay | "Hide grid", "Cancel" |
| Drill down into the grid | "<number>" |
| Drill down multiple steps at once | "Mouse grid <number> <number> <number> <number> <number>" |
| Revert grid to previous state | "Undo", "Undo that" |
| Mark an object to drag | "Mark", "Mark <number>" |
| Drop the marked object | "Drag" |

**Control mouse and keyboard**
| To do this | Say this |
|---|---|
| Left click | "Click", "Tap", "Left click" |
| Right click | "Right click" |
| Double-click | "Double-click" |
| Triple-click | "Triple-click" |
| Press a key | "Press <key>" |
| Press a key multiple times | "Press <key> <count> times" |
| Press a key combination | "Press <key1> <key2>...", "Press <key1> and/plus <key2>..." |
| Press and hold a key | "Press and hold <key>" |
| Release the held key | "Release <key>", "Release" |
| Dismiss a menu/flyout (Esc) | "Dismiss" |
| Backspace | "Backspace" |
| Enter (new line while dictating) | "Enter" |
| Tab | "Tab" |
| Delete | "Delete" |
| Move mouse continuously in a direction | "Move mouse <direction>" |
| Move mouse a fixed distance | "Move mouse <direction> <distance>" |
| Drag mouse in a direction | "Drag mouse <direction>" |
| Increase/decrease pointer speed | "Move faster", "Faster", "Move slower", "Slower" |
| Stop moving the mouse pointer | "Stop", "Stop moving" |

**Dictate text**
| To do this | Say this |
|---|---|
| Insert text | "<text>" |
| Insert a voice access command as literal text | "Type <voice access command>", "Dictate <voice access command>" |
| Insert text and capitalize first letter of each word | "Caps <text>" |
| Insert text with no leading space | "No space <text>" |
| Open the touch keyboard | "Show touch keyboard", "Show keyboard" |
| Close the touch keyboard | "Hide touch keyboard", "Hide keyboard" |
| Spell out text letter by letter | "Spell out" |
| Spell out selected/last-dictated text | "Spell that" |
| Correct selected/last-dictated text | "Correct that" |
| Correct specific text | "Correct <text>" |
| Improve recognition of a hard word | "Add to vocabulary" |
| Turn on fluid dictation | "Turn on fluid dictation" |
| Turn off fluid dictation | "Turn off fluid dictation" |

**Select text**
| To do this | Say this |
|---|---|
| Select last dictated text | "Select that" |
| Select all text | "Select all" |
| Select specific text | "Select <text>" |
| Select a range of text | "Select from <text 1> to <text 2>", "Select <text 1> through <text 2>" |
| Select previous/next word | "Select previous word", "Select last word", "Select next word" |
| Select N previous/next words | "Select previous <count> words", "Select last <count> words", "Select next <count> words" |
| Select previous/next character | "Select previous character", "Select last character", "Select next character" |
| Select N previous/next characters | "Select previous/backward/last/forward/next <count> characters" |
| Select previous line | "Select previous line", "Select last line" |
| Select N previous/next lines | "Select previous/backward/last/forward/next <count> lines" |
| Select previous/next paragraph | "Select previous paragraph", "Select last paragraph", "Select next paragraph" |
| Select N previous/next paragraphs | "Select previous/last/next <count> paragraphs" |
| Select current word at cursor | "Select word", "Select this word" |
| Select current line at cursor | "Select line", "Select this line" |
| Select current paragraph at cursor | "Select paragraph", "Select this paragraph" |
| Clear selection | "Unselect that", "Clear selection" |

**Edit text**
| To do this | Say this |
|---|---|
| Delete selected/last-dictated text | "Delete that", "Scratch that", "Strike that" |
| Delete specific text | "Delete <text>" |
| Delete all text | "Delete all" |
| Delete previous/next character | "Delete previous/last/next character" |
| Delete N previous/next characters | "Delete previous/last/next <count> characters" |
| Delete previous/next word | "Delete previous/last/next word" |
| Delete N previous/next words | "Delete previous/last/next <count> words" |
| Delete previous line | "Delete previous line", "Delete last line" |
| Delete N previous/next lines | "Delete previous/last/next <count> lines" |
| Delete previous/next paragraph | "Delete previous/last/next paragraph" |
| Delete N previous/next paragraphs | "Delete previous/last/next <count> paragraphs" |
| Delete current word/line/paragraph at cursor | "Delete word/this word", "Delete line/this line", "Delete paragraph/this paragraph" |
| Cut selected/last-dictated text | "Cut that" |
| Cut N previous/next chars/words/lines/paragraphs | "Cut previous/last/next <count> characters/words/lines/paragraphs" |
| Copy selected/last-dictated text | "Copy that" |
| Copy N previous/next chars/words/lines/paragraphs | "Copy previous/last/next <count> characters/words/lines/paragraphs" |
| Paste | "Paste", "Paste here", "Paste that" |
| Undo | "Undo that" |
| Redo | "Redo that" |
| Remove all whitespace from selected/last-dictated text | "No space that" |
| Insert text with no leading space | "No space <text>" |

**Format text**
| To do this | Say this |
|---|---|
| Bold specific text | "Bold <text>", "Boldface <text>" |
| Italicize specific text | "Italicize <text>" |
| Underline specific text | "Underline <text>" |
| Bold/italic/underline selected or last-dictated text | "Bold that", "Italicize that", "Underline that" |
| Capitalize first letter of a word | "Capitalize <word>" |
| Uppercase a word | "Uppercase <word>", "All caps <word>" |
| Insert text with each word capitalized | "Caps <text>" |
| Lowercase a word | "Lowercase <word>", "No caps <word>" |
| Capitalize/uppercase/lowercase selected or last-dictated text | "Capitalize that", "Cap that", "Uppercase that", "All caps that", "Lowercase that", "No caps that" |
| Apply an action to N previous/next words/lines/paragraphs/characters | "<action> previous/last/next <count> words/lines/paragraphs/characters" (action = bold, italicize, underline, capitalize, uppercase, or lowercase) |

**Navigate text**
| To do this | Say this |
|---|---|
| Insert a new line | "New line" |
| Insert a new paragraph | "New paragraph" |
| Move cursor before/after specific text | "Move before/after <text>", "Insert before/after <text>" |
| Go to top/bottom/end of document | "Go to top", "Go to bottom", "Go to end", "Go/Move to beginning/start/end of document" |
| Go to beginning/end of word | "Go/Move to beginning/start of word", "Go/Move to end of word" |
| Go to beginning/end of line | "Go/Move to beginning/start of line", "Go/Move to end of line" |
| Go to beginning/end of paragraph | "Go/Move to beginning/start of paragraph", "Go/Move to end of paragraph" |
| Move cursor N steps in a direction | "Move/Go <direction> <count> times" |
| Move cursor N characters left/right | "Move/Go left/right/forward <count> characters" |
| Move cursor N words left/right | "Move/Go left/right <count> words" |
| Move cursor N lines up/down | "Move/Go up/down/back <count> lines" |
| Move cursor N paragraphs up/down | "Move/Go up/down <count> paragraphs" |
| Move cursor to beginning/end of selection | "Move/Go to beginning/end of selection" |

**Dictate punctuation marks**
| To insert | Say this |
|---|---|
| . | "Period", "Full stop" |
| , | "Comma" |
| ? | "Question mark" |
| ! | "Exclamation mark", "Exclamation point" |
| 's | "Apostrophe-s" |
| : | "Colon" |
| ; | "Semicolon" |
| " " | "Open quotes", "Close quotes" |
| - | "Hyphen" |
| ... | "Ellipsis", "Dot dot dot" |
| ' ' | "Begin single quote", "Open single quote", "End single quote", "Close single quote" |
| ( ) | "Left parentheses", "Open parentheses", "Right parentheses", "Close parentheses" |
| [ ] | "Open bracket", "Close bracket" |
| { } | "Left brace", "Open brace", "Right brace", "Close brace" |

**Dictate symbols**
| To insert | Say this |
|---|---|
| * | "Asterisk" |
| \ | "Backslash" |
| / | "Forward slash" |
| \| | "Vertical bar", "Pipe character" |
| _ | "Underscore" |
| ¶ | "Paragraph sign", "Paragraph mark" |
| § | "Section sign" |
| & | "Ampersand", "And sign" |
| @ | "At sign" |
| © | "Copyright sign" |
| ® | "Registered sign" |
| ° | "Degree symbol" |
| % | "Percent sign" |
| # | "Number sign", "Pound sign" |
| + | "Plus sign" |
| - | "Minus sign" |
| × | "Multiplication sign" |
| ÷ | "Division sign" |
| = | "Equals sign" |
| < > | "Less than sign", "Greater than sign" |
| $ | "Dollar sign" |
| £ | "Pound sterling sign" |
| € | "Euro sign" |
| ¥ | "Yen sign" |

**Correction flow (detail)** — Source: https://support.microsoft.com/en-us/accessibility/windows/voice-access/correct-text-with-voice
- Say "Correct <text>" or "Correct that" → opens a correction window with numbered alternative-text suggestions.
- Say "Click <number>" to accept an alternative (replaces the originally selected text).
- Say "Spell that" (or "Click <number>" for the "Spell that" list entry) to manually spell the correct word.
- Recommended to correct **one word at a time**; multi-word corrections yield worse suggestions.

**Modes (detail)** — Source: https://support.microsoft.com/en-us/accessibility/windows/voice-access/get-started-with-voice-access
- **Default mode**: seamless mix of commands and dictation (no UI indicator shown).
- **Commands mode**: every utterance is treated as a command, no dictation ("Commands mode" UI label shown).
- **Dictation mode**: every utterance is treated as text to insert, no commands ("Dictation mode" UI label shown).
- No distinct "spell mode" exists — spelling is a command ("Spell out" / "Spell that"), not a separate mode.
- No explicit wake *word* in the marketing sense; the closest equivalent is the phrase "Voice access wake up" (or "Unmute") used to move from Sleep to Listening state.
