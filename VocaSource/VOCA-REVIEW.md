# VOCA application review

Reviewed September 11, 2026 · VOCA Preview 0.1.0 (2)

**Follow-up implemented:** The workflow refinements and four proposed features below are now implemented. See [VOCA-WORKFLOW-REVIEW.md](VOCA-WORKFLOW-REVIEW.md) for current results; this document preserves the earlier review and release findings.

## Overall assessment

VOCA now reads as a distinct macOS dictation utility. The notch, destination icon, ink-blue surfaces, system blue controls, and restrained typography form a coherent identity. The app still shares FluidVoice’s feature architecture and much of its implementation. It is a GPL fork, and a familiar user will recognize the provider/model/shortcut organization. It should describe that ancestry honestly in acknowledgments.

Keep this visual direction. The next investment should be a dependable first-use experience and a smaller number of everyday decisions, not another wholesale redesign.

## Changes completed in this pass

- Added interactive native Liquid Glass to navigation controls and grouped the Overview navigation surfaces in a GlassEffectContainer. Reading panels remain opaque.
- Added short page transitions, consistent Settings entry/exit timing, restrained status-text changes, and native document-window opening/closing behavior. The shared motion policy and native window behavior respect Reduce Motion. No animation was added to dictated characters.
- Replaced the practice TextEditor/overlaid placeholder with a native NSTextView whose placeholder shares TextKit’s font, container, and origin. Bound updates follow an end cursor, preserve interior selections, clamp shorter text safely, and do not overwrite marked text composition.
- Corrected shared glass-button label styling and the style editor’s sheet background. Made common Settings descriptions wrap and moved previous-version actions into a disclosure.
- Rebuilt What’s New around this VOCA preview. Removed upstream issue/release/support/sponsorship destinations from product flows. Manual update actions explain the actual preview status; background update polling is inactive.
- Replaced the upstream feedback submission forms with local exports, including history examples. Feedback drafts persist locally. Exporting does not add logs or credentials.
- Removed the inherited analytics key from the app configuration and added a VOCA-specific guard in AnalyticsConfig. Verified the packaged key is empty. Updated the privacy UI to match.
- Added a local Help guide and accessible GPL/source acknowledgments. Collected notices from the 17 packages in the Xcode lockfile and included them in the app. One dependency still needs licensing clarification below.
- Updated GitHub workflow/artifact labels, issue templates, and funding configuration. Internal Swift target names and historical provenance remain intact. These repository workflows were not run on GitHub.
- Assigned VOCA its own preview version, 0.1.0 (2).

## Verification

360 distinct selected regression tests passed across two completed runs (233 and 133 executions, with six repeated tests). Coverage includes:

- Shortcuts and notch lifecycle; Settings navigation and routing.
- Text-editor cursor/selection updates, Unicode lengths, and marked composition.
- Provider request bodies and temperature support; thinking-tag removal.
- Dictionaries, punctuation, spoken formatting, and transfer/backup compatibility.
- History entry compatibility, per-app prompt routing, model-cache validation, and media-pause state handling.
- Audio-buffer conversion, supported file extensions, and speaker-turn merging.
- VOCA analytics isolation and rejection of the upstream release feed.

Final build and deep signature verification passed. GitHub YAML parsed successfully and all five policy JavaScript files passed syntax checks. SwiftLint is not installed in this environment; strict lint was not run. Existing compiler warnings include Swift 6 concurrency migration warnings in upstream services.

In the running app, inspected Overview, Speech Models, Writing Styles and its editor, Dictionary, Text Enhancement, Command Mode, file transcription, History, Usage, Feedback, What’s New, Help, and all seven Settings sections. Exercised native typing and clearing, model search, Settings search, return navigation, opening/dismissing sheets, and exporting a test feedback file to a temporary folder. The tested export contained only its draft and app version. Model search found the six Whisper entries without activating or downloading a model.

Ad-hoc rebuilds repeatedly required Microphone and Accessibility permission renewal during the review. This was a code, regression, and interface review—not a complete live dictation certification. Microphone capture, insertion into Word/ChatGPT, every downloadable model, paid API calls, Intel hardware, sleep/wake cycles, and multi-display notch behavior were not re-tested. The fixture-based Whisper Tiny transcription test was excluded; it is separately marked as nondeterministic in the inherited CI workflow. Accessibility fallback code was reviewed, but a full VoiceOver/Increase Contrast/Reduce Transparency matrix was not performed.

## Usability and visual findings

| Finding | Priority | Recommendation |
| --- | --- | --- |
| Ad-hoc rebuilds invalidate permissions and make a working app appear broken | Release blocker | Use a stable Developer ID identity, hardened release configuration, and notarization; test upgrades from a previously authorized build. |
| No VOCA update or support service exists | Release blocker | Configure an owned release channel and support destination before selling. Current UI is truthful and keeps feedback local. |
| Media-control dependency licensing is not fully established | Release blocker | Obtain license clarification for the exact pinned fork or replace it with an implementation that has clear redistribution terms. |
| History’s two-column minimum widths can enlarge a small window | Moderate | Make History adapt to a single-column list/detail flow at narrow widths. |
| Settings still contain dense explanations, and some direct rows can truncate at small widths | Moderate | Continue the common wrapping treatment and consolidate permission guidance into one setup area. |
| Writing Styles exposes raw prompt syntax and several configuration states | Moderate | Add optional plain-language starter templates and keep raw instructions in Advanced. Preserve the existing editor for experienced users. |
| Many model choices have similar names and descriptions | Moderate | Offer a measured recommendation based on this Mac and selected languages, while retaining the full library. |
| Usage has more milestones and repeated totals than an everyday utility needs | Minor | Lead with time saved and a weekly trend; collapse milestones. |
| Some provider artwork has weak contrast on dark surfaces | Minor | Give dark provider logos an appropriate neutral icon plate and verify both appearances. |
| Singular/plural copy in Usage is inconsistent | Minor | Clean up strings such as “1 days” and “1 active days.” |

The first-read hierarchy is now clear: page title, main task, secondary configuration. Standard window controls, a visible sidebar, native text fields, and plain labels are worth keeping. The notch is the most distinctive interaction. Keep its destination icon and audio-driven waveform; avoid turning it into a busy dashboard.

The shared opaque palette’s previously measured secondary-text contrast is 6.22:1 in light mode and 8.25:1 in dark mode. Metadata on raised dark panels is 4.87:1. Those measurements apply to explicit opaque pairs, not every translucent or native control; they are not a blanket accessibility certification.

## Commercial distribution

The source is GPLv3. A one-time paid download is allowed, while recipients keep their GPL rights. A digital binary release must offer the corresponding source, including VOCA modifications and the scripts needed to build it, in a GPL-compliant way. Preserve copyright/license notices and mark modifications. A closed, non-redistributable license for this fork would require separate permission from the relevant rights holders. See the [GNU GPL FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#DoesTheGPLAllowMoney) and [GPLv3 sections 4–6 and 10](https://www.gnu.org/licences/gpl.html).

The current build is not cleared for commercial release. The pinned [mediaremote-adapter fork](https://github.com/ejbills/mediaremote-adapter) has no root license file. Several files identify BSD 3-Clause licensing, while some headers have separate copyright notices and the Swift wrapper has no stated project-wide grant. Its README also describes using Apple’s private MediaRemote framework. This is a dependency and distribution-channel review issue, not evidence that GPL prohibits charging money.

Model weights, provider terms, artwork, trademarks, and third-party packages need their own review. The collected notices are an inventory aid, not a legal clearance. Have the final distribution terms and dependency rights reviewed before launch. Start with a signed direct download; evaluate Mac App Store eligibility separately. Apple documents the release-signing/notarization process in [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

A plausible product offering is a paid, maintained installer with dependable updates and support. The price should fund maintenance; it cannot depend on preventing GPL-authorized copying. User-supplied API credentials also avoid promising unlimited cloud processing for a one-time payment.

## Next improvements

1. **Destination check.** A guided, local test that confirms permissions, identifies the target app/field, and verifies insertion into a user-chosen scratch field. This addresses the most repeated failure in this project.
2. **Safer recovery.** A visible, optional undo-last-insertion action tied to the original target and text revision. Existing cleanup undo/history recovery should be the foundation; do not delete text the user edited afterward.
3. **Recommended setup.** Benchmark supported local models with a small bundled sample, then recommend a model for the user’s languages and Mac. Keep real timing/memory results and the full library available.
4. **Quick controls.** A compact keyboard-accessible chooser for an existing microphone, writing style, and model, using the same settings rather than duplicating their state.

Per-app rules, custom vocabulary, local/API cleanup, shortcuts, history, and file transcription already exist. Improve their discoverability and reliability before presenting them as new features.
