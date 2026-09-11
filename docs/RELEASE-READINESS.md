# Release readiness

**Decision: not ready for public paid app distribution.** The app and website are a usable development preview. Do not confuse a successful build with a completed software business.

## Implemented in this pass

Personal writing-style analysis, twelve templates, optional pause-aware finish, a three-second resettable countdown, slow-cleanup feedback and bounded waiting, original-word recovery, guarded delivery after delayed processing, a restored draggable permission helper, and opt-in detailed diagnostics. Website copy now explains these features and their limits. Purchase/download actions are gated by `releaseReady`.

## Distribution blockers

| Area | State | Next concrete action |
| --- | --- | --- |
| Developer ID / notarization | Local app is ad-hoc signed. Rebuilds can invalidate TCC registrations. | Owner supplies a valid signing identity; build Release, notarize, staple, assess with Gatekeeper, test upgrades. Scripts support a hardened signing path but it has not been validated with a real identity. |
| Media-control dependency | The exact pinned mediaremote-adapter fork lacks a clearly established project-wide license and uses private MediaRemote APIs. | Obtain documented rights for the exact revision or replace it; evaluate distribution-channel policy separately. Do not claim legal clearance from a successful link step. |
| Models and assets | Source notices are retained; model choices have separate terms. | Review each bundled/downloaded asset and model for intended distribution. The app repository does not bundle model weights. |
| Checkout / support | Public endpoints, seller identity and terms are not configured. | Configure and test actual checkout, receipts/refunds, support email and source archive access. |
| Source delivery | Development repository is private. | Give binary recipients the corresponding source/build scripts; archive matching source for each release. |
| Supported matrix | Apple Silicon local tests; no complete multi-app/macOS/hardware certification. | Test Word, ChatGPT/browser editors, TextEdit, secure fields, app switching during cleanup, multiple displays, mic disconnection, noisy rooms, long pauses, sleep/wake, and macOS 15/26. |

## Fixed during review

- Slow cleanup cannot wait forever or insert a late second result.
- Automatic finish cannot send a message and does not end silent startup or a stream with missing audio frames.
- Changed destination fields after deferred processing cause recovery instead of opportunistic insertion.
- The Accessibility helper no longer closes simply because System Settings briefly disappears during another permission dialog.
- Detailed logs are off until explicitly enabled; old inherited “always collect” behavior was removed, and common credential formats are redacted. Existing files are not deleted.
- Public web copy no longer presents proposed pricing as a completed purchase offer or makes an untested universal speed/accuracy comparison.

## Run before release

1. `VocaSource/scripts/test-voca.sh` and a clean Release build from a fresh source checkout.
2. `npm run check && npm run build` plus desktop/mobile keyboard and browser checks.
3. Sign with Developer ID, notarize using the owner's credentials, staple the ticket.
4. Run `scripts/release-check.sh VOCA.app` with documented dependency clearance, source URL, and support email. Environment flags alone are not evidence of legal clearance.
5. Set real site configuration only after the above. Run `node scripts/site-release-check.mjs`.
6. Ship a small opt-in beta, gather real latency/accuracy reports across representative speech, then open sales.

Apple references: [Developer ID](https://developer.apple.com/developer-id/), [notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

The website can be published as a clearly labeled informational preview with sales disabled. It is not a production app launch.
