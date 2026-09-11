# VOCA workflow review

September 11, 2026 · VOCA Preview 0.1.0 (2)

## Completed

- Settings now uses compact preference rows, optional explanation popovers, a shared permission/destination setup flow, and disclosures for secondary controls. Long descriptions wrap in narrow layouts. Search can reveal collapsed groups.
- Dictionary is a searchable Phrase Library with an inline composer, editable entries, and a compact three-sample voice-learning indicator. Manual phrases, recorded training, boosting, punctuation, and import/export remain available.
- Writing Styles provides Natural, Concise, Email, and Notes templates in a two-column picker. Advanced prompt editing and existing provider/shortcut routing remain available.
- History changes from two columns to list/detail navigation when its content width is below 720 points. Usage leads with estimated time saved, recent activity trends, and an optional milestones disclosure.
- The new Near the Typing Cursor position uses the original destination icon and waveform in a compact pill. It prefers above the caret, then below or either side when space requires, clamps to the target display, and falls back to the screen edge if cursor geometry is unavailable. Notch and bottom positions remain supported. Cursor mode hides transcript controls that do not apply to its compact presentation.
- Destination checker opens a chosen running app and allows six seconds to place a cursor in a disposable draft. It verifies the exact field, avoids selected text/password fields, uses the existing insertion path, and confirms the resulting text. Failures have actionable explanations. It never sends Return.
- One in-memory insertion receipt enables conservative undo. Exact UTF-16 validation preserves later appends; edits elsewhere in the captured document cause refusal. Undo uses a precise selected-text replacement, never blind Command-Z or whole-field replacement. Closed, unreadable, or unsupported fields retain a manual copy recovery path.
- Model setup includes a measured CPU/memory recommendation and a separate real ASR timing operation for the selected installed local model. Timing uses a bundled sample, warmup, and three measured runs without history, insertion, or cloud requests. The full model library remains available.
- Quick Controls opens with Command-K and uses native keyboard-accessible model, microphone, and writing-style pickers. Existing settings, per-app rules, and dedicated shortcuts retain precedence.
- Review found a startup Keychain block. Startup now uses noninteractive reads; an explicit Unlock Saved API Keys control performs authentication off the main thread. Failed access cannot overwrite or discard unread migrated credentials.

## Verification

**386 selected automated tests passed with zero failures** in the completed September 11 06:10 run. Coverage includes the new Unicode-safe recovery and caret-placement logic, stale receipt rejection, overlay preference compatibility, model advice, benchmark fixture packaging, and Keychain migration/write protection, plus existing dictation, shortcuts, provider requests, dictionaries, navigation, history, audio conversion, and privacy regressions.

The exact result is `DerivedData/Logs/Test/Test-Fluid-2026.09.11_06-10-41-+0300.xcresult`. The final follow-up change only hides irrelevant caret-mode Settings controls and updates its visual preview; it was compiled and packaged afterward.

Live checks on this Mac:

- Microphone and Accessibility both show Allowed in the checker after refreshing the current build's macOS registration and restarting stale duplicate processes.
- TextEdit destination check inserted `VOCA insertion check.` at the intended cursor after a `Before: ` prefix. The checker reported Verified.
- After appending ` Keep this edit.`, Undo insertion removed only the check text. The resulting document was exactly `Before:  Keep this edit.`.
- Local practice recording completed and produced text. Its temporary practice result was cleared afterward.
- Command-K, Quick Controls, destination sheet, Phrase Library, template preview/cancel, compact History list/detail navigation, Usage trends/disclosures, and narrow Settings were exercised in the running app.
- Real installed Parakeet TDT v3 timing completed: about 0.04 seconds for the bundled 1.2-second sample, approximately 30.6× realtime, median of three warm runs. This is a short-sample measurement, not a guarantee for arbitrary recordings or a transcription-accuracy benchmark.
- The compute check measured approximately 1769 GFLOPS on this 16 GB, 10-core Mac and recommended Parakeet as a starting point. Other model/hardware recommendations remain heuristics.

## Practical limits

The UI automation interface cannot synthesize a modifier-only global shortcut or feed its app-targeted synthetic key events through the global shortcut recorder. It therefore could not validate a real Right Option press or visually certify the new cursor pill during external-app recording. The existing shortcut was preserved. Caret geometry, display-edge fallback, and position persistence have automated coverage, but the actual caret pill still needs a manual recording pass in TextEdit, Word, and browser editors.

Precise undo depends on the destination exposing readable text/ranges and selected-text replacement. It is intentionally conservative about edits inside the recorded document. Only TextEdit was live-tested for this recovery path; no claim is made that every app supports it.

Paid API providers were not called. Unlocking existing saved API keys requires the user's system Keychain authentication. No credentials were read or printed during review. Every downloadable model, Intel hardware, disconnected-device handling, external-display caret geometry, and sleep/wake behavior were not live-tested. The inherited nondeterministic Whisper Tiny fixture test remained excluded.

The app remains a FluidVoice-derived GPL fork even though its everyday UI and new workflows are now distinct. Original capabilities and provenance remain. The earlier release findings still apply: stable Developer ID signing/notarization, an owned update/support channel, and dependency licensing clearance are needed before commercial distribution. Ad-hoc rebuilds can invalidate macOS permission registrations.
