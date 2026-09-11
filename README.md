# VOCA

**Your voice. Your pace. Your Mac.**

Native macOS dictation for people whose best sentence occasionally starts with “um, wait.” Speak into the app you're already using, choose your speech model, and add optional local or cloud text cleanup.

[Source](https://github.com/InstinctEx/VOCA) · [Report a bug](https://github.com/InstinctEx/VOCA/issues) · [Build it yourself](#install-or-build) · [Installation guide](docs/BETA-INSTALL.md)

> **Free public beta · Apple Silicon · macOS 15+**
> [Download the free beta](https://github.com/InstinctEx/VOCA/releases/tag/beta-2026-09-12), or build from source. All local features are included, without an account or activation key. The app is **not Apple-notarized**; macOS may require manual installation approval. Optional cloud API usage costs extra through your provider. Donations are optional; no donation page is configured yet.

VOCA is a GPLv3 fork of [FluidVoice](https://github.com/altic-dev/Fluid-oss). We're building on that foundation openly, with our own interface and writing workflow. The keyboard may get a holiday. The attribution stays.

## The parts that make it VOCA

| The daily annoyance | VOCA's answer |
| --- | --- |
| “Where are my words going?” | Destination app icon, insertion checker, and guarded delivery after delayed processing. |
| “I paused to think.” | Optional 3/7/12-second thinking time, followed by a three-second countdown. Speaking resets it. |
| “This sounds like an HR department wrote it.” | Twelve editable writing templates, custom prompts, and a personal style derived locally from examples you provide. |
| “The AI is still considering my five-word email.” | Slow-cleanup warning after eight seconds, use-original-now control, and a thirty-second deadline. |
| “Undo deleted my next sentence.” | Verified insertion recovery preserves subsequent appends; uncertain edits are refused. |
| “Where did that setting go?” | Quick controls for model, microphone, and writing style. |
| “Why does my dictation app need a trophy room?” | Measured speaking pace, estimated time saved, and activity trends; milestones stay optional. |

The interface uses SwiftUI/AppKit, native glass where available, and a compact waveform at the notch, screen edge, or near the caret. Precise placement and insertion depend on the destination app's Accessibility support. Automatic finish never presses Send. Quiet is a clue, not a mind-reading API.

## Local cleanup: the server is your Mac

**VOCA Polish** uses Qwen3-4B-Instruct-2507, 4-bit, through MLX Swift. Download the model once—approximately **2.28 GB**—and enhance offline without an API key, Ollama, or another companion app. Apple Silicon is required; 16 GB memory is recommended alongside speech recognition.

The model gets no tools or network access for inference. Downloads can resume, memory can be released, and a sample editor shows local results and timing. Model weights are **not included in the app ZIP**. See [local-model setup](VocaSource/docs/VOCA-POLISH.md).

A recent bug made cleanup answer a dictated request instead of editing it. The local engine now uses a transcript-data envelope, escaped chat delimiters, editing examples, and conservative output checks. Rejected cleanup falls back to original words. We tested the reported phrase across all twelve templates, plus questions and English/Greek instruction-like text. This is a mitigation, not a claim that a language model can never make a mistake. [Technical notes](VocaSource/docs/TRANSCRIPT-BOUNDARY.md).

## Writing styles

Natural · Concise · Email · Notes · Friendly · Professional · Straight to it · Technical · Journal · Social post · Meeting recap · Formal.

Templates are editable starting points, not twelve locked personalities. Create a style in **Writing Styles → New Style → Custom instructions**, select VOCA Polish or a configured provider, then choose it for dictation. Reselect a template to adopt its latest instructions; updates do not overwrite your saved custom prompts.

**Sounds like me** analyzes at least 80 words of examples locally for sentence length, paragraphing, casing, contractions and punctuation. It saves the style instructions you review, not the example text. No background typing surveillance; your personality is not a telemetry event. If you later use a cloud cleanup provider, it receives the saved instructions with the text to process.

## Measurements, with the footnotes still attached

| Measurement | What was actually checked |
| --- | --- |
| **About 20 MiB ZIP / 57 MiB installed** | September 12 beta after removing debug/local executable symbols, down from roughly 27 / 108 MiB. Global/exported symbols and runtime resources retained. Model downloads are additional. |
| **3.38 seconds** | One local Qwen sample in the smaller packaged app on a 16 GB Apple Silicon Mac. A smoke check, not a general latency promise. |
| **30.6× realtime** | Parakeet v3, 1.2-second bundled sample, median of three warm runs, 16 GB/10-core Apple Silicon, September 11. Not an accuracy benchmark or competitor comparison. |
| **414 app tests passed** | September 12 regression run: 418 selected, four opt-in model/audio tests skipped, zero failures. Real Qwen adversarial tests were run separately for the preceding cleanup fix. |
| **Six website tests passed** | Release configuration and preview-server file isolation; syntax checks and static build also passed. |

English/Greek switching is improved when speech contains a pause. Seamless code-switching, every destination app, and every supported Mac are not certified. We have not measured competitor accuracy. There are no invented “99.9%” claims here. The spreadsheet was devastated.

## Other capabilities

- Downloadable speech engines including Whisper and Parakeet, subject to model/hardware compatibility.
- Local Qwen, configurable cloud cleanup, and compatible local-server endpoints. A chat subscription does not automatically include API credits.
- Custom shortcuts, per-app style routing, dictionary/vocabulary tools, punctuation rules, and file transcription.
- History, separate audio-retention controls, export/backup, microphone selection and local diagnostics.
- Optional pause/resume for **Music and Spotify**, through their public scripting interfaces. Open the player and use **Allow Music / Allow Spotify** in settings. Other players and browser media are not controlled. The unresolved private MediaRemoteAdapter dependency has been removed.

## Install or build

The current beta targets **Apple Silicon, macOS 15 or newer**. Native Liquid Glass requires macOS 26. Local testing is on macOS 26.4.1; the broader hardware/OS matrix remains open.

A prebuilt download needs no Xcode. An unnotarized download may require manual approval in **System Settings → Privacy & Security**. Microphone/Accessibility setup is still necessary; ad-hoc updates can require renewed permission. Follow [Apple's guidance](https://support.apple.com/en-us/102445), not a random command that disables Gatekeeper.

To build from source, use Xcode with the macOS 26 SDK and Metal toolchain:

```sh
xcodebuild -downloadComponent MetalToolchain
cd VocaSource
VOCA_BUILD_CONFIGURATION=Release ./build-voca.sh
./scripts/test-voca.sh
```

Packages download on a clean build. `VOCA_PACKAGE_CACHE` can point to an existing SourcePackages cache. The app is produced at `../VOCA.app`, locally signed without a paid Apple Developer account. Internal scheme/module names retain upstream names.

Release packaging strips debug/local executable symbols and re-signs the result; retain Xcode's separate dSYM locally when available. From a clean, committed checkout matching the app:

```sh
scripts/package-beta.sh /path/to/VOCA.app /fresh/output/directory
```

This produces `VOCA-beta.zip`, `VOCA-source.zip`, an installation guide, source revision and SHA-256 checksums. No upload occurs. Tests do not replace live Word/browser insertion, multi-display, microphone-disconnection, update-permission or consented Music/Spotify testing.

## Website

```sh
npm run dev       # http://localhost:5173
npm test
npm run check
npm run build     # static files in dist/
```

No npm dependencies; Node 20+. `config.js` contains public download, source, release-note and optional donation links—never secrets. Run `node scripts/site-release-check.mjs` to validate free-release configuration. Donations never gate downloads. Upload only `dist/` to Cloudflare Pages; app/source archives are hosted on GitHub Releases.

## Credit, licence and support

VOCA is a **GPLv3 fork of [FluidVoice](https://github.com/altic-dev/Fluid-oss)**, based on `42e33e68ec473129ad090521e56c22c912a16db3`. Its speech/provider foundations remain. VOCA adds its interface, destination/recovery workflow, personal styles, pause handling and local Qwen integration. Original notices remain. Credit is not a UI bug.

The prebuilt beta and source are free. Every local feature stays available without donating. Optional support can help fund development, signing/notarization and broader testing; it does not promise a delivery date or unlock features. Provider fees, downloaded models and assets have their own terms.

Each binary release includes matching source, build revision and checksums. The September 12 binary was built from `5272c4b2a48a80decbb1206f87a537d4a6fb56aa`; its historical source documentation mentions an earlier paid-download proposal, which has been superseded by free distribution. The app executable has not changed for this distribution update.

Contributions and reproducible bug reports are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md); do not include API keys, personal recordings, or private dictation in an issue.

See [LICENSE](LICENSE), [changes](VocaSource/VOCA-CHANGES.md), [third-party notices](VocaSource/THIRD-PARTY-NOTICES.txt), and [remaining compatibility work](docs/RELEASE-READINESS.md).

## Repository map

- `VocaSource/`: active app, tests, notices and build scripts.
- `index.html`, `styles.css`, `app.js`, `public/assets/`: website.
- `config.js`, `release-config.js`: public release configuration and validation.
- `scripts/`: beta packaging and release checks.
- `docs/`: installation, release status and [draft launch posts](docs/SOCIAL-POSTS.md).

Build caches, app bundles, model weights, recordings, local databases and credentials are excluded. The repository is not a twelve-gigabyte scrapbook of Xcode's feelings.
