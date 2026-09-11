# Release readiness — 12 September 2026

**Current target: a locally signed, unnotarized beta. Paid sales are not open.** The owner does not have a paid Apple Developer account. An optimized Release build does not require that account, but it does not gain Developer ID trust or Apple notarization. Installation may require manual approval; ad-hoc updates can require renewed Accessibility permission.

## Completed engineering work

- Removed the unresolved `ejbills/mediaremote-adapter` package, framework linkage, import, and notice from the active app. Optional pause/resume now uses public Music/Spotify scripting interfaces. No global media-key toggles, private MediaRemote framework or bundled Perl adapter. The UI states the narrower player support and exposes explicit Automation permission actions. Actual player integration still needs consented live testing.
- Preserved the Qwen transcript-boundary fix and twelve refined writing styles. Original-text recovery remains the fallback for rejected cleanup.
- Shared browser/CLI sales validation now requires real checkout, binary, source and terms URLs, seller identity, support address, and explicit beta disclosure. Setting `releaseReady` alone cannot enable checkout.
- Website changed from the old €49 proposal to a planned €5 beta download with all local features included. It discloses the installation limitation. No payment flow is fabricated.
- Local preview server serves only public website files, not repository or user files.
- Added `scripts/package-beta.sh`: produces a binary ZIP, matching tracked-source ZIP, source revision, install guide and SHA-256 checksums. It refuses dirty tracked source and existing output archives. Nothing is uploaded automatically.
- Added `docs/BETA-INSTALL.md` with Apple's per-app approval path; no Gatekeeper-disable or quarantine-removal commands.

## Evidence

Optimized Release build succeeded after an explicit nonisolated destructor avoided a Swift 6.3.3 optimizer crash in the generic cleanup race. The packaged app passes deep/strict signature verification and contains no MediaRemoteAdapter framework.

App: 418 selected tests, 414 passed, four opt-in real-model/audio tests skipped, zero failures. Website: six release/server regression tests passed, syntax checks passed, static build passed. Browser verified €5 disclosure and the closed-checkout dialog. The preceding Qwen-only change was separately exercised with the installed real model across all twelve styles and adversarial English/Greek fixtures.

## Still required before public paid beta

| Item | Remaining work |
| --- | --- |
| Seller and checkout | Owner chooses provider and supplies public seller name, owned support email, terms/refund policy, real checkout link. Real purchase, receipt and refund tests require that account. |
| Hosting and source delivery | Upload the binary and corresponding source together to accessible hosting; verify downloads. Private GitHub is not accessible source delivery for customers. Do not publish the repository merely because open sourcing was discussed. |
| Live compatibility | Consent-based Music/Spotify pause/resume, Word, ChatGPT/browser editors, secure fields, app switching during cleanup, multiple displays, mic disconnection, sleep/wake, noisy rooms, and macOS 15/26 across supported hardware. Automated tests do not substitute for this matrix. |
| Models/assets | Packaged source notices have no missing-license placeholders after adapter removal. Qwen/MLX notices are included. Downloaded speech models and API services have their own terms; review the selected distribution catalog before sales. No model weights are bundled. |
| Installation | Test the downloaded ZIP on a different Mac/account, including quarantine, Accessibility and update behavior. This machine's existing TCC registration cannot prove a first-install experience. |

## Verification commands

- `npm test && npm run check && npm run build`
- `VOCA_PACKAGE_CACHE=/path/to/SourcePackages VocaSource/scripts/test-voca.sh`
- Build with Xcode configuration Release, then `VOCA_BUILD_CONFIGURATION=Release VocaSource/scripts/package-voca.sh`.
- From a clean matching source checkout: `scripts/package-beta.sh /path/to/VOCA.app /fresh/output/directory`.
- `VOCA_DISTRIBUTION_CHANNEL=unsigned-beta scripts/release-check.sh /path/to/VOCA.app` still requires documented dependency review and real source/support details before it reports a distribution pass.
- `node scripts/site-release-check.mjs` intentionally fails while seller/download fields are unset.

A later notarized edition requires a valid Developer ID certificate, hardened signing, Apple's notary submission, stapling, and Gatekeeper verification. The standard release gate still enforces those requirements by default.

References: [Apple installation guidance](https://support.apple.com/en-us/102445), [Developer ID](https://developer.apple.com/developer-id/), [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).

## Smaller beta package

Release packaging now removes debug/local executable symbols before re-signing. The trial retained the complete global/exported symbol list, launched successfully, and ran a local Qwen sample in 3.38 seconds. ZIP reduced from 28,312,041 to approximately 21,421,184 bytes (24.3%); installed app from about 108 to 57 MiB. Future archive bytes may vary with included notices. Runtime/model resources remain intact; model downloads are still separate. No new full regression run was needed for this packaging-only change.
