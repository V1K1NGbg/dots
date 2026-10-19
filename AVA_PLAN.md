# AVA — Advanced Virtual Assistant

Implementation plan · 2026-10-19

## 1. Goal and agreed scope

Create a local-first virtual assistant for Arch Linux and Hyprland. AVA is an animated female 3D character with a Cortana-inspired personality, a Cortana–Hatsune Miku-inspired appearance and voice, continuous English conversation, and persistent memory.

Decisions established during planning:

- Run AVA and inference on the same machine: Ryzen AI 9 HX 370, 64 GB RAM, integrated graphics, no external GPU.
- Connect to a configurable local llama.cpp server, initially using Qwen3.8-27B-Uncensored Q4_K_M.
- Keep language models replaceable without losing AVA's personality, voice, or memory.
- Use a 3D anime-style avatar, displayed in a bottom-left desktop popup.
- Start listening through a keyboard shortcut, then continue hands-free until the conversation is stopped.
- Support English speech initially.
- Give AVA only the desktop operations actually exposed by the existing Rofi setup, with one restriction: Rofi Run becomes application launching only. AVA cannot execute arbitrary shell or CLI commands.
- Draw AVA's colors and popup styling from the current system theme.
- Treat file/project reading, browser context, and screen understanding as a separately scoped later phase. Rofi access does not implicitly authorize these capabilities.

The first complete release includes conversation, an animated avatar, voice, memory, and the restricted desktop tools. Finished character artwork and voice selection are explicit deliverables, rather than assuming a placeholder is the finished product.

## 2. Existing foundations

Workspace inspected: `/Users/victor/test/dots`, branch `hyprland`.

| Existing component | Source | Relevance |
| --- | --- | --- |
| Hyprland configuration | `config/.config/hypr/hyprland.lua` | Lua configuration, shortcuts, monitor events, and window rules |
| Desktop behavior | `config/.config/hypr/lua/desktop.lua` | Existing sticky-window and keep-on-top behavior |
| Local inference | `config/.config/systemd/user/llama-cpp.service` | Already selects the requested Qwen model |
| Rofi launcher | `config/.config/rofi/launcher.sh` | Defines the existing desktop utility entry points |
| Rofi operations | `config/.config/rofi/modi/` | Reusable actions, including timers and media controls |
| System palette | `config/.config/alacritty/alacritty.toml` | Main colors and Monocraft font |
| Popup styling | `config/.config/rofi/theme.rasi` | Panel colors, cyan borders, and corner radius |
| Screen capture/OCR | `config/.config/hypr/scripts/screenshot.sh` | Existing grim, slurp, and Tesseract integration |
| Miku companion | `config/.config/miku/` | Existing desktop companion lifecycle; its sprite renderer is not a 3D VRM renderer |
| Installation | `install.sh`, `update.sh`, `backup.sh` | Integration with the current dotfile workflow |

These files establish repository configuration, not proof of the installed Arch machine's current runtime state. Implementation begins by checking installed versions and effective configuration on that machine.

## 3. User experience

Proposed shortcut: **Super+A**, unused in the inspected Hyprland configuration.

1. Press the shortcut to show AVA and begin a conversation.
2. AVA indicates when she is listening, processing, performing an action, or speaking.
3. Speak normally; speech detection determines the end of each turn.
4. AVA responds with streamed speech, subtitles, facial expressions, gestures, and mouth movement.
5. Speaking over AVA interrupts her response and starts the next turn.
6. Press the shortcut again, use the stop control, or say “AVA, stop listening” to end the session and release the microphone.

The popup must not steal focus when summoned for voice conversation. Text entry, history, memory inspection, and settings use an explicitly focusable panel. Include microphone status, mute, and a text-only interaction path.

Stop microphone capture on desktop lock and suspend. After a crash or session restart, recover into a non-listening state; do not replay unfinished desktop actions. Handle microphone removal and output-device changes visibly.

Anchor the avatar to the bottom-left of the chosen monitor, with configurable size and margins. Reposition on monitor removal or scale changes. Use click-through behavior for the passive avatar surface and an interactive panel for controls. Pause rendering when hidden and reduce its frame rate while idle.

## 4. Character design

### Personality

AVA's name is **Advanced Virtual Assistant**. Her character should feel like a capable, familiar teammate:

- Intelligent, composed, observant, and dependable.
- Warm and lightly sarcastic, with occasional playful teasing.
- Concise and practical while completing a task.
- More conversational when the user is simply chatting.
- Honest about uncertainty and whether an action actually succeeded.

Store her persona and example dialogue in an editable character file, independent of the model. Personality instructions must not be the mechanism enforcing tool restrictions.

Example tone:

> “Morning. Your project's where you left it. Shall we finish it before you invent another side quest?”

### Appearance and system palette

Use an original Cortana–Miku-inspired character: teal twin-tails, expressive anime eyes, a futuristic charcoal outfit, luminous circuit details, and a blue holographic shimmer.

| Color | Intended use |
| --- | --- |
| Mint cyan `#67ffeb` | Main accent, hair highlights, eyes, and circuit lines |
| Electric blue `#35ddff` | Holographic glow and projection effects |
| Violet `#9359ff` | Restrained secondary accents and hair gradients |
| Charcoal `#191919` | Main outfit and popup background |
| Panel charcoal `#242424` | Popup cards and secondary surfaces |
| Gray `#404040` | Dividers and subdued outlines |
| Off-white `#f8f8f2` | Text and bright details |
| Muted gray `#aaaaaa` | Secondary text |
| Pink `#ff025f` | Small contrasting accessories |

Popup styling follows Rofi: Monocraft Nerd Font, thin cyan borders, and 6px rounded corners. Tune character and panel transparency separately so her face and subtitles remain readable. Listening and error states must be distinguishable through text/icons as well as color.

Avatar requirements:

- Replaceable VRM asset with a humanoid rig and facial expressions.
- Idle breathing, blinking, head movement, and hair physics.
- Listening, thinking, speaking, and action-result poses.
- Audio-driven mouth motion initially, with more accurate mouth shapes during polish.
- Modest holographic effects that leave graphics resources available for inference.

Use a suitable placeholder during technical development. Create and rig AVA's finished model using VRoid/Blender or an artist workflow. Validate the finished asset in the actual renderer, including expression and hair behavior.

## 5. Architecture

| Component | Initial choice |
| --- | --- |
| Desktop shell and controller | Electron + TypeScript |
| 3D rendering | Three.js + `@pixiv/three-vrm` |
| Chat inference | Existing llama.cpp HTTP server |
| Speech recognition | whisper.cpp; start with `base.en`, compare `small.en` |
| Speech detection | Silero VAD |
| Speech synthesis | Pocket TTS on CPU |
| Voice design | Qwen3-TTS VoiceDesign during asset preparation |
| Persistent memory | SQLite with full-text search |
| Desktop integration | Fixed tools wrapping existing actions, Hyprland IPC, and systemd user services |

One AVA controller owns conversation state, memory writes, and desktop tool execution. Rendering and microphone capture communicate with it through a narrow IPC interface. Keep model inference in existing local runtimes and off the UI thread. Bundle UI assets locally so inference and conversation can operate offline after setup.

Use packaged or pinned dependencies and a lockfile. Resolve exact versions during implementation against the target Arch environment. Avoid building a general plugin framework, a separate memory server, or a second task scheduler.

Project AIRI was investigated as an existing foundation. Its avatar and speech features are relevant, but its public roadmap still marks persistent memory unfinished. The recommended route is a focused AVA application using established rendering and speech libraries.

### Wayland integration gate

Electron's ordinary window-position and always-on-top APIs have Wayland limitations. Hyprland must own placement and stacking using the existing Lua configuration and relevant window events.

Before building the full UI, prove transparency, bottom-left placement, workspace visibility, click-through behavior, focus handling, and multi-monitor/scaling behavior on the actual desktop. Check interaction with the existing sticky/keep-on-top logic rather than adding competing focus or stacking hooks.

## 6. Language model and hardware tuning

Current repository configuration:

```text
Base URL: http://127.0.0.1:8080/v1
Model ID: qwen3.8-27b-uncensored
Repository: JonathanColetti/Qwen3.8-27B-Uncensored-GGUF
File: Qwen3.8-27B-Uncensored-Q4_K_M.gguf
Server context: 32768
Parallel slots: 1
Idle sleep: 10 seconds
```

The model card lists approximately 16.8 GB of weights; runtime buffers, context, graphics, and audio require additional memory. The machine's 64 GB capacity is promising, but it does not establish conversational latency or how much memory the Vulkan driver can use effectively.

Expose configurable server URL, model ID, context/response limits, sampling settings, and model-specific reasoning/tool-call options. Keep speech models, voice reference, and avatar independently configurable.

For model replacement:

1. Load the desired model in the configured server.
2. Select or update AVA's model profile.
3. Verify streaming, context formatting, reasoning separation, and tool-call support.
4. Preserve character settings and the memory database.

Initially disable extended reasoning for ordinary spoken conversation and use concise streamed answers. Speak user-facing answer text only, not reasoning fields or tool payloads. Bound the prompt using recent turns, a summary, and retrieved relevant memories.

Benchmark CPU and Vulkan execution with the avatar, speech recognition, and synthesis running together. Measure warm and cold response latency, token generation, memory pressure, and thermal behavior. Compare short and longer conversations. Keep speech workloads on CPU initially and tune thread counts to avoid starving the desktop.

The existing one-slot server may be busy with Rofi Ask AI. Show bounded waiting/error states and allow cancellation. Measure the ten-second sleep policy's wake-up cost before changing it. Server tuning and model swaps must also be checked against Rofi's existing AI client.

No throughput or end-to-end latency has been measured on the target hardware yet. If the requested model is too slow, present the measured tradeoff before choosing another model.

## 7. Voice and continuous conversation

Target voice: clear, feminine, bright, slightly synthetic, and musical, with Cortana-like confidence and measured delivery.

Voice preparation:

1. Generate several candidate voices with Qwen3-TTS VoiceDesign.
2. Select and refine a clean AVA reference sample.
3. Evaluate that reference with Pocket TTS and save a reusable voice state.
4. Apply subtle effects after synthesis rather than baking effects into the reference sample.
5. Approve the result through listening tests across normal dialogue, questions, numbers, and technical terms.

Pocket TTS's preservation of the designed voice is an evaluation item, not an assumed result. Keep the larger voice-design model out of the live loop. Retain the original reference audio so voice states can be regenerated after a TTS model change.

```text
Microphone
  → echo cancellation
  → voice activity / turn detection
  → whisper.cpp transcription
  → AVA controller + memory + llama.cpp + permitted tools
  → streamed text chunks
  → Pocket TTS
  → playback + subtitles + avatar animation
```

Requirements:

- Tune silence thresholds and speech padding so pauses do not cut off a sentence.
- Use echo cancellation with AVA's playback as a reference; evaluate browser audio processing and PipeWire's echo-cancel module on the actual setup.
- Verify full-duplex interruption with both headphones and speakers.
- On interruption, cancel generation and playback, discard queued speech, and ignore late events from the cancelled turn.
- Track generated versus actually spoken content so the next turn does not assume the user heard an interrupted answer in full.
- Execute only complete, validated tool calls. Never execute a partially streamed call.
- Keep microphone and playback device selection recoverable when devices disconnect or change.
- Recognize the stop-listening command without waiting for an LLM decision.
- Keep a text interaction path available when an audio component fails.

## 8. Memory and data lifecycle

Store the database under `~/.local/share/ava/`, outside version-controlled configuration.

Memory layers:

1. **Conversation history:** retained user and assistant turns, with completion/interruption status.
2. **Durable facts:** user preferences, project details, and explicit “remember this” requests, with source references and revisions.
3. **Session summaries:** derived context for resuming older conversations efficiently.

Provide memory inspection, correction, deletion, and export through the UI and conversational commands. Distinguish user-provided facts from assistant guesses; an inference must not silently become an authoritative personal fact. Corrections supersede previous facts while preserving their provenance until deletion.

Use SQLite full-text search and bounded summaries initially. Evaluate semantic embeddings only if representative recall checks reveal a need.

### Retention and compatibility invariants

- Retain conversation history and durable facts until deletion or an explicitly configured retention policy applies.
- Raw microphone audio and intermediate audio buffers are transient by default. Temporary audio does not become a hidden transcript archive.
- Summarization does not delete or overwrite retained original messages.
- Model replacement never resets memory or changes the database format.
- Forgetting removes the relevant active memory and invalidates derived summaries/search entries. Where retained source messages contain the forgotten information, the deletion operation must also remove the relevant source material or exclude it from future recall and extraction.
- User exports and database backups are separate snapshots with explicit retention/deletion controls; deleting active memory must not be described as deleting independent exports.
- Database migrations are transactional and versioned. Older binaries refuse incompatible writes. Before rollback, preserve post-upgrade records; never silently replace the database with an older snapshot that discards new data.

### Writers, concurrency, and failures

The AVA controller is the sole database writer. UI operations, conversation completion, memory extraction, and summarization submit mutations through it.

| Writer/event | Required result |
| --- | --- |
| New conversation turn | Commit the turn and its state atomically; incomplete output remains identifiable |
| Explicit remember or correction | Save the source and fact/revision together; the active fact points to the current revision |
| Background extraction/summary | Check source revisions before committing; discard results based on changed or deleted sources |
| Forget or retention expiration | Remove affected active data and invalidate derived entries in the same transaction |
| Model swap | Change inference configuration only; retain all memory records |
| Crash/restart | Recover committed data without replaying tool side effects |
| Schema upgrade/rollback | Prevent concurrent mixed-version writers and preserve records written after the upgrade |

Durable memory and scheduled actions must never depend on expiring runtime locks or caches. Test deletion while summarization is in flight, correction after a summary was created, restart recovery, and memory retention across a model swap.

## 9. Strict Rofi-equivalent desktop tools

The final restriction replaces the earlier proposal for a general command runner:

> AVA may perform only operations explicitly exposed by the existing Rofi setup. Run is restricted to launching registered applications. There is no arbitrary shell/CLI execution capability.

Before implementation, inventory the actual Rofi menus and nested actions. For each tool, record the corresponding existing operation and its accepted arguments. Do not expose additional features merely because an underlying command supports them.

The inventory includes the existing app/file opening, window selection, music/audio, timer/alarm/stopwatch, clipboard, calculator/spelling, network, display, and power functions. Match their current behavior, ranges, and available actions exactly. AVA's own conversation and memory operations are separate internal features.

### Application-only launching

Expose `launch_app(app_id)` using registered installed desktop applications:

- Resolve a fixed application ID through the application's desktop entry using standard desktop-launch facilities.
- Keep executable paths, shell strings, and arbitrary launch arguments out of the model-facing interface.
- Do not accept arbitrary `.desktop` files supplied as tool arguments.
- Normal file opening is a separate tool matching the existing Rofi Files behavior.
- Do not provide terminal command injection, simulated typing, or another generic execution tool that bypasses the restriction.

The fixed tool implementations will necessarily call system utilities such as `playerctl` and `wpctl`. Those invocations use code-defined commands and validated arguments; they are not a model-controlled command runner.

### Shared implementation and reliability

- Enforce the tool catalog and argument schemas in code, independently of prompts and model output.
- Reuse existing noninteractive entry points wherever available.
- For menu-only actions, extract the action into a shared function used by Rofi and AVA, preserving existing callers and interfaces.
- Preserve existing IDs, file-path handling, device checks, and error reporting. Do not interpolate model-provided values into shell or Lua code.
- Validate resource IDs against current enumerated applications, windows, devices, or clock entries.
- Report success only after an operation returns a successful result. Distinguish partial completion from total failure.
- Bound tool execution and avoid automatic retries when a side effect may already have occurred.

Timers and alarms continue through `config/.config/rofi/modi/time.sh`. Rofi, AVA, and systemd firing/reconciliation all use that script's existing lock and durable clock state. AVA must not directly write `clocks.json`, create a competing scheduler, or erase a saved timer when scheduling fails. Test simultaneous Rofi/AVA changes and recovery after scheduling or notification failure.

## 10. Later phase: files, browser, and screen context

The user identified these three interests. Keep them explicitly separate from the initial Rofi-only desktop access and discuss their exact read scope before implementation.

| Integration | Proposed behavior |
| --- | --- |
| Files and projects | Search configured roots and read relevant files on demand, returning paths and bounded source excerpts |
| Firefox | Extension providing tab metadata, selected text, and readable page content through native messaging |
| Screen | On-request capture/OCR using the existing desktop tools; image understanding after verifying the matching vision projector |

Use source labels and capture timestamps. Treat retrieved files, web pages, and screen content as reference data, not tool-execution instructions. Do not automatically turn all retrieved app content into permanent personal memory.

Firefox needs an extension/native-host integration; filesystem access alone is not a reliable current-tab API. Screen pixels and OCR are different from structured app data, and some browser/system surfaces will be inaccessible. Surface those limits accurately.

## 11. Proposed implementation locations

- `apps/ava/` — Electron/TypeScript application, local runtime integration, and focused tests.
- `config/.config/ava/` — configuration defaults, personality, and visual settings.
- `config/.config/systemd/user/dots-ava.service` — on-demand desktop application lifecycle.
- `config/.config/hypr/hyprland.lua` — shortcut and AVA-specific window integration.
- `config/.config/rofi/modi/` — only the shared action changes needed to preserve Rofi/AVA parity.
- `install.sh`, `update.sh`, and `backup.sh` — installation, upgrades, and configuration handling consistent with current patterns.
- `~/.local/share/ava/` — runtime memory and local character/voice assets.

Large model downloads and runtime memory stay outside Git. Ordinary dotfile backup must not accidentally collect conversation databases or raw audio. Keep AVA single-instance and ensure normal application shutdown cleans up only the inference helpers it owns, not the shared llama.cpp service.

## 12. Delivery stages

| Stage | Deliverable | Acceptance gate |
| --- | --- | --- |
| 1. Feasibility | Placeholder overlay and combined-load hardware benchmark | Correct Hyprland transparency/placement/focus; measured warm/cold conversation latency |
| 2. Character chat | Persona, streaming text, configurable model connection | Model swap preserves character settings; busy/loading/unavailable server states recover cleanly |
| 3. Voice conversation | Shortcut, continuous listening, streamed speech, interruption | Multi-turn conversation with headphones and speakers; no self-triggering; stop/lock releases microphone |
| 4. Memory | History, durable facts, recall, correction, forgetting | Restart/model-swap persistence; deleted facts do not return through summaries or concurrent jobs |
| 5. Desktop tools | Exact Rofi action catalog with application-only launching | Real action outcomes, no unsupported operations, no arbitrary command path, concurrent Rofi compatibility |
| 6. Character polish | Finished avatar, chosen voice, expressions, and lip motion | Visual/listening review on the real desktop while inference is active |
| 7. Application context | Separately scoped file, Firefox, and screen integrations | Accurate source references, bounded retrieval, and explicit handling of unavailable data |

The first technical milestone is a talking placeholder avatar on the actual Arch machine. Stages 1–6 complete the initial companion; stage 7 is the later context-reading extension.

## 13. Verification checklist

Use focused tests for the conversation state machine, tool boundary, memory lifecycle, and shared action behavior. Complement them with actual desktop/audio checks:

- Stream cancellation prevents late text/audio from returning and prevents incomplete tool execution.
- Server disconnects and helper failures leave a recoverable text/UI state.
- Only registered app IDs launch; executable strings, injected arguments, arbitrary desktop files, and unknown actions are rejected before process creation.
- Every desktop tool maps to a current Rofi operation, including its limits; no generic utility arguments leak through.
- File paths with spaces or unusual characters remain data, never executable code.
- Memory corrections/forgetting remain effective across restart, summarization, model swaps, and supported migrations.
- Concurrent Rofi/AVA timer operations retain all valid changes; saved timers remain recoverable after scheduler failure.
- Existing Rofi behavior still works after shared action extraction.
- Avatar placement survives workspace switches, monitor hotplug, and scaling changes without disrupting focus.
- Microphone state matches the visible indicator; mute/stop/lock actually ends capture.
- Playback interruption and echo cancellation work on the intended speakers, microphone, and Bluetooth devices.
- Measure speech-to-first-audio latency and UI smoothness with all components active; record results rather than promising an unmeasured target.
- After assets are downloaded, ordinary conversation works with networking disabled and without an automatic cloud fallback.

Live Arch, microphone, visual, and performance validation was unavailable during planning. The major unresolved risks are 27B conversational latency on shared integrated graphics, full-duplex audio behavior, and the artistic iteration needed for AVA's finished model and voice.

## 14. Research references

- [llama.cpp server API and configuration](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)
- [Requested Qwen3.8-27B-Uncensored GGUF model](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF)
- [Electron window APIs and Wayland limitations](https://www.electronjs.org/docs/latest/api/base-window)
- [Three.js VRM support](https://github.com/pixiv/three-vrm)
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- [Pocket TTS](https://github.com/kyutai-labs/pocket-tts)
- [Qwen3-TTS voice design](https://github.com/QwenLM/Qwen3-TTS)
- [PipeWire echo cancellation](https://docs.pipewire.org/page_module_echo_cancel.html)
- [Firefox native messaging](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging)
- [Project AIRI and its public roadmap](https://github.com/moeru-ai/airi)
