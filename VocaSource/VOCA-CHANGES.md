# VOCA — original FluidVoice foundation

Upstream commit: 42e33e68ec473129ad090521e56c22c912a16db3 (GPLv3).

This is a fresh export of the original source. VocaNative is retired; none of its dictation, shortcut, model, or provider implementations are used here.

Changes: VOCA app identity and artwork, refreshed shared theme, navigation icons, feature search with clear control, isolated bundle/keychain identity, and a guard against installing upstream releases over VOCA.

Original speech models, API providers, AI enhancement, custom shortcuts, target insertion, notch/bottom overlay, dictionary, file transcription, history, audio controls, and settings are retained.

The upstream private Fluid Intelligence runtime is not included in the public repository. Its existing conditional integration is retained; no replacement runtime is claimed. VOCA automatic updates need a separate release channel.

## Purple glass design

Fixed the sidebar overlap by placing its header and footer outside the scroll view. Added native macOS 26 glass with material and reduced-transparency fallbacks, a muted purple default, quieter navigation, and an Overlay appearance preview. The compact recording pill shows the destination icon and live waveform; enabled live preview appears in a separate transcript strip. Larger overlay options remain available. Recognition, insertion, provider networking, and shortcut handling are unchanged by this design update.

Validation: application build and signature verification succeeded; 124 selected upstream regression tests passed. Sidebar layout and Overlay appearance preview were checked in the running application. Live recording was not exercised during this visual pass.

## Notch dictation

The first launch of this update selects MacBook Notch / Icon & Waveform. Dictation opens around the physical camera notch using the original DynamicNotchKit controller, with a destination icon, lavender audio-reactive bars, and a softer opening animation that respects Reduce Motion. Empty live previews no longer reserve a blank strip. The notched display stays the anchor when using an external monitor; closed-lid and notchless setups retain the upstream floating fallback. Bottom placement and expanded controls remain selectable in Overlay settings.

Validation: build and signature verification passed; 108 existing shortcut and settings navigation tests passed. Live microphone recording remains unverified because this ad-hoc build reports missing permissions.

## Native page interiors

Replaced the inherited Overview checklist with a readiness panel, shortcut display, navigation tiles, and practice editor. Rebuilt Speech Models as a searchable library with visible download/activation controls, progress, cancellation, language selection, and a model detail sheet. Writing Styles uses quiet style rows, a simpler editor, and expandable routing/advanced settings. Dictionary separates phrases, vocabulary, and punctuation; typed phrase entry is the initial composer, with voice training still available. Provider connections use a single scrolling list. File transcription, Command Mode, Usage, and shared panels follow the same spacing and typography. Native macOS 26 glass is used for controls, with earlier-system fallbacks.

The notch now contracts through DynamicNotchKit before its panel is removed. Completion returns immediately to the insertion pipeline, and generation checks protect a newer recording from an old hide task. Packaged binaries no longer search the development PackageFrameworks folder.

Validation: 126 regression tests passed, including two new notch lifecycle tests. Final builds and deep signature checks passed. Overview, model search/details, dictionary, style editor, and provider navigation were inspected in the running app. No speech recordings, provider keys, downloaded models, or saved phrases were added during UI verification; microphone dictation was not re-tested.

## Ink appearance and native blue

Adopted native adaptive blue as the default accent, with a one-time migration from the previous palette. Replaced purple/gray content surfaces with deep ink-blue dark surfaces and paired soft-white light surfaces. Corrected the main detail background that had masked the theme. Removed decorative title glass tiles, made unselected navigation symbols neutral, and changed the notch waveform to white. Added stronger secondary text colors and opaque, outlined shared surfaces for accessibility preferences. The recognition, insertion, shortcuts, and notch timing code were not modified in this appearance update.

Validation: final application build, packaging, and deep signature verification passed. Light and dark appearances were inspected, including the model library and a narrower window. The practice button uses an explicit white label, and Overview navigation cards reserve equal text space. Color-pair measurements and review limits are documented in VOCA-APPEARANCE-REVIEW.md. The final rebuilt copy reports that Microphone and Accessibility access need enabling again; dictation was not re-tested during this pass.

## Glass, motion, product identity, and application review — September 11, 2026

VOCA Preview 0.1.0 (2) adds interactive navigation glass, brief page/status transitions, consistent Settings entry/exit, native window animation, and reduced-motion handling. The native practice editor aligns placeholder and cursor using TextKit and preserves selections during bound updates. Shared button labels, the style sheet, and compact Settings rows were refined.

What’s New and Help now describe VOCA. Upstream support, release, sponsorship, and feedback destinations were removed from product flows; feedback and history examples export locally. The inherited analytics key was removed and VOCA analytics are disabled at the configuration boundary. GPL provenance is preserved and dependency notices are bundled. GitHub labels/templates use VOCA; the internal Swift module names remain compatible.

Validation: 360 distinct selected regression tests passed. Builds, packaging, deep signature verification, workflow YAML parsing, policy JavaScript syntax, native editing, feedback export, searches, and main-screen navigation were checked. See VOCA-REVIEW.md for the exact limits, remaining product issues, and commercial-distribution blockers. Live microphone capture and cross-app insertion need revalidation after stable signing and permissions. This preview is not a commercially cleared release.


## September 11, 2026 — Cursor and workflow pass

- Added a compact cursor-anchored recording pill. It uses Accessibility caret bounds, stays within the display work area, follows the captured field, and falls back to the screen edge when bounds are unavailable.
- Added destination verification using a clearly labeled test phrase in a chosen running app. Protected fields, selected text, changed focus, missing permission, and unverifiable results receive distinct explanations. Nothing is submitted.
- Added an in-memory last-insertion receipt and recovery controls. Undo changes only the verified inserted range, restores replaced text, preserves later appends, and refuses other document edits. It never sends a blind Command-Z.
- Added Quick Controls (Command-K and menu-bar entry) for installed models, microphones, writing styles, and recovery. Changes use the existing services and are blocked while recording or preparing a model.
- Added a local Accelerate hardware benchmark with a memory/architecture-aware model recommendation, plus a bundled-speech timing check for installed local models. Speed measurements are separated from accuracy claims.
- Rebuilt the phrase library as a searchable inline list; replaced the training ring with a small sample progress indicator. Added Natural, Concise, Email, and Notes writing templates with an advanced prompt editor.
- Made History switch to a list/detail flow in narrow windows. Usage now leads with estimated time saved and trends; milestones and records are collapsed.
- Refined Settings with native groups, on-demand explanations, shorter copy, wrapping labels, and collapsible secondary options. Permission setup links to a real destination check.
- Fixed a startup hang from interactive Keychain reads. Reads during startup fail promptly when access is unavailable; explicit unlocking occurs in the background. Failed migrations retain their source keys, and an unreadable aggregate cannot be overwritten.

## September 11, 2026 — Personal voice and patient finishing (0.2.0 preview)

- Expanded writing templates to twelve; added locally inferred, reviewable personal style from explicitly provided examples. Raw examples are not persisted or sent as prompt content.
- Added optional pause-aware finish with 3/7/12-second thinking time, a three-second countdown, speech reset, extra time for some unfinished English phrases, and per-recording keep-listening. Automatic finish does not submit messages.
- Added slow-cleanup feedback at eight seconds, original-word bypass, a thirty-second deadline, and suppression of late responses. Deferred results check the original destination before insertion.
- Restored and redesigned the floating Accessibility app-drag helper. It stays open during transient System Settings dialogs.
- Made detailed diagnostics explicitly opt-in; redacted common credential formats. Corrected Apple Speech privacy copy to reflect possible Apple service processing.
- Added release-signing configuration, read-only release gates, a reproducible selected regression script, a private-source repository layout, and truthful website feature/benchmark copy. Public sales remain disabled until release prerequisites are met.

## VOCA Polish — Qwen 4B

Built-in Apple Silicon enhancement using Qwen3-4B-Instruct-2507 (4-bit) and MLX Swift. Pinned, SHA-256-verified downloads support pause/resume and deletion. No API key or companion server is required. Writing styles and personal instructions feed the local editor. Incomplete or numerically altered output is rejected for original-word recovery. Model weights unload on memory pressure or after an idle interval. A local sample editor reports measured processing time.

## Neutral VOCA interface
- Replaced the inherited local intelligence logo with VOCA's shared waveform mark.
- Introduced warm-white and graphite surfaces, restrained typography, quieter cards and control-only glass.
- Grouped enhancement providers by On this Mac / Cloud services / Your server; retained existing models, verification and custom endpoints.
- Added a Downloaded speech-model filter and compact active-engine summary; refined overview and dictionary presentation.
- Separated verified provider identity and controls to prevent narrow-window clipping.

## Dashboard and navigation
- Added real history metrics and seven-day activity to Overview, with clearly labeled time-saved estimates.
- Made disclosure labels full-row keyboard-accessible buttons throughout the app and Settings.
- Removed the top scroll-edge overlay and automatic Settings inset adjustment; clipped detail content to its viewport.
- Added descriptive Settings navigation and direct setup/help actions.

## Language transitions and cursor placement
- Added switch-at-pauses decoding for Parakeet v3, enabled by default with a Speech Models toggle. Sustained quiet splits phrases; uninterrupted language changes remain a model limitation.
- Added a conservative local-cleanup check for removal of Greek or Latin text spans.
- Cursor pill prefers above-right, then above-left/below/side positions as space permits. Failed caret reads discard the old anchor, use the field perimeter, or fall back to the display's upper-right edge.
- Added English/Greek synthetic inference checks and screen-edge placement regressions.

## Measured speaking pace
- Overview shows duration-weighted speaking WPM and total recording time, updating after saved dictations.
- Speaking pace counts raw transcript words and includes pauses; AI-expanded text cannot inflate it.
- Saved-time estimates across Overview, Usage, and today's stats subtract measured recording and known transcription/cleanup time from the user's typing baseline.
- Timing persists independently of audio storage. Legacy untimed history remains readable and uses an explicitly labeled 150 WPM fallback; no measured pace is invented for it.

## Hotkey listener recovery
- Fixed startup retries recursively returning to attempt one forever. Retries now stop after five attempts and are canceled when a new initialization replaces them.
- Listener health changes now update Settings directly, including delayed success and a disabled tap.
- Removed a competing three-second startup reset; recovery checks run every five seconds after setup finishes.
- Replaced endless initializing indicators with an unavailable message and a Restart listener action. Active listeners also expose a restart action.

## Custom Qwen writing styles
- Verified VOCA Polish is now available in the custom-style provider picker, with its verified local model selected automatically.
- The fixed preset explains where to create custom Qwen instructions.

## Local cleanup instruction boundary and writing templates

Reproduced and corrected Qwen answering dictated instructions instead of editing them. Transcript input is serialized as data, chat-control delimiters are escaped, editing examples preserve requests and speaking roles, and a conservative assistant-reply check falls back to original words. Refined all twelve writing templates without overwriting saved custom instructions. Added real-model adversarial fixtures and isolated provider-routing tests from saved Everyday model selections. See docs/TRANSCRIPT-BOUNDARY.md for scope and limitations.

## Unsigned beta preparation

Removed the unresolved private media adapter. Optional media pause now targets Music and Spotify through their public scripting interfaces, with explicit Automation setup and same-track resume. Other players/browser media are not controlled. Added a locally signed Release distribution path and source/checksum packaging; public sales remain unconfigured. Validation: 414 app tests passed, four opt-in tests skipped; six website tests passed. Live player permissions and broad destination/hardware testing remain beta work.
