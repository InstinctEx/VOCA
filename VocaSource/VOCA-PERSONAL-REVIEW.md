# VOCA 0.2.0 — personal, patient, recoverable

Review date: September 11, 2026. This is a development build, not a certified distribution release.

## What changed

- Twelve writing templates and a local, opt-in writing-sample analyzer. At least 80 words produces editable instructions about sentence length and punctuation; this is a simple heuristic, not a trained personal language model. No background typing collection. Samples are cleared when opening the reviewed draft.
- Optional automatic finish: 3/7/12 seconds of thinking time, followed by a three-second countdown. New speech resets it; clicking the countdown keeps listening for the current recording. Initial silence and missing audio frames cannot trigger completion. An unfinished English phrase gets extra time. Quiet cannot prove intent. Toggle-mode dictation only; automatic finish never sends a message.
- Dictation cleanup warns after eight seconds and falls back after thirty. “Use original words now” bypasses waiting. A late provider result is discarded. A local engine may still finish its computation after cancellation; it cannot deliver a second answer through this cleanup path.
- Deferred insertion requires the captured field, otherwise text is retained for recovery. The existing precise undo declines unsafe changes instead of issuing a blind system Undo.
- Restored the draggable Accessibility helper, with native material, actual app icon, Finder action and explicit dismissal. It no longer disappears merely because System Settings temporarily vanishes.
- Detailed diagnostics are explicitly opt-in, with credential redaction and an accurate warning about dictated text. Existing logs are not automatically removed. Apple Speech privacy text now acknowledges possible Apple processing.
- Countdown available in compact and expanded dictation indicators. Existing notch/caret placement, destination checker, model benchmark, quick controls, responsive History and simplified Usage retained.

## Validation and limits

400 selected macOS tests passed with zero failures in the September 11 run, including silence/pause transitions, cleanup timeout/late-result isolation, explicit bypass, style analysis, and diagnostic consent/redaction. The final package builds successfully. The website passes its syntax check and production build.

Live UI verification exercised synthetic writing samples through analysis and the editable draft, then discarded the draft and confirmed samples cleared. No personal sample was uploaded. The Accessibility action opened the correct System Settings pane and permission polling confirmed access; the floating panel closed when access was recognized, so its full drag interaction remains a manual beta check. The website was inspected at desktop and 390-pixel mobile widths; a narrow feature-card layout defect was found and corrected. Cross-application insertion and conservative recovery had prior TextEdit checks; this is not a certification of every editor.

Automatic finish still needs a real beta with thinking pauses, background speech, varied microphones and accents. Global modifier-only shortcuts could not be synthesized by the UI test driver. Live paid API timing and every provider/model combination were not tested. The deadline applies to ordinary dictation cleanup; command/edit and historical reprocessing remain separate paths.

## Product judgment

The visual presentation and patient/recoverable workflow give VOCA its own direction. The underlying implementation is still a FluidVoice fork and broad feature categories remain recognizable. Retain the dependable transcription/model/provider system and required attribution. Differentiate through behavior, restraint, and understandable recovery rather than removing useful functionality to look different.

Next priorities: beta feedback on pause timing; measure end-to-end latency locally with clear consent; improve personal-style fidelity using user-approved correction examples; reduce setup failures across real editors; complete the release engineering checklist before more feature expansion. Avoid passive collection or claims that a silence detector can read intent.

## Distribution decision

**Not ready for paid public distribution.** See [release readiness](../docs/RELEASE-READINESS.md) and [monetization](../docs/MONETIZATION.md). Developer ID/notarization, dependency rights, actual checkout/support/source delivery, and a broader beta remain. A private development repository does not remove GPL obligations when distributing binaries. The website is suitable as an informational preview with sales disabled.
