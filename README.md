# VOCA

**Your voice. Your pace. Your Mac.**

A native macOS dictation app for people whose best sentence occasionally starts with “um, wait.”

VOCA puts words where you write, gives you room to think, and lets you choose the speech model and cleanup provider. It does not need a dashboard to explain that you are talking. Humanity has had a reasonably successful beta of talking already.

> **Status: private development preview. Not cleared for public app distribution.**
> The website builds and can be reviewed as a preview. Purchases remain disabled. See [release readiness](docs/RELEASE-READINESS.md) before putting a download or checkout in front of customers.

## What makes it VOCA?

VOCA is a GPLv3 fork of [FluidVoice](https://github.com/altic-dev/Fluid-oss), based on commit `42e33e68ec473129ad090521e56c22c912a16db3`. Its speech/provider foundations remain. The VOCA work is the redesigned native interface and the surrounding experience: permission guidance, destination verification, conservative recovery, personal style, patient finishing, and an escape route from slow AI.

Credit is not a UI bug. We keep the original copyright notices. The app can have its own character without pretending its grandparents do not exist.

| The daily annoyance | VOCA’s answer |
| --- | --- |
| “Did it type into the right app?” | Destination icon, a guided insertion checker, and guarded delayed delivery. |
| “I paused to think.” | Optional 3/7/12-second thinking time, then a 3-second countdown. Resume speech to reset; tap to keep listening. |
| “This sounds like an HR department wrote it.” | Twelve templates plus **Sounds like me**, a local analysis of writing examples you choose. |
| “The AI is still thinking about a five-word email.” | A warning after 8 seconds, an immediate original-words option, and a 30-second cleanup deadline. |
| “Undo ate the words I typed afterward.” | Verified range-based undo preserves later appends and refuses uncertain edits. |
| “Which model should I download?” | A Mac compute check and real timing for an installed local speech model. |
| “Where was that setting again?” | **⌘K**: model, microphone, and writing style in one small chooser. |
| “Why does my dictation app need a trophy room?” | Usage leads with estimated time saved and trends. Milestones can stay folded. |

This combination is our product position, not proof that every competitor lacks these features. Other apps also support local models and custom workflows. We have not run a controlled competitor accuracy or latency comparison. We are selling a thoughtful workflow, not an imaginary gold medal.

## VOCA Polish: the server is your Mac

Built-in Qwen3-4B-Instruct-2507, 4-bit, powered by MLX Swift. A 2.28 GB verified download gives Apple Silicon Macs local text enhancement without installing Ollama, opening a terminal, or finding an API key in a drawer. Your writing styles work with it; the model gets no tools or network access for inference.

Pause/resume downloads, memory release, a local sample editor with timing, and original-word recovery are included. 16 GB memory is recommended alongside speech recognition. See [setup and exact limits](VocaSource/docs/VOCA-POLISH.md). No, a model running locally does not magically become incapable of making mistakes.

## Writing styles

Natural · Concise · Email · Notes · Friendly · Professional · Straight to it · Technical · Journal · Social post · Meeting recap · Formal.

Templates are editable starting points. They instruct cleanup to preserve facts and avoid inventing details. A prompt is still not a guarantee: review important writing.

**Sounds like me** needs at least 80 words of examples. It measures sentence length, paragraphing, casing, contractions, and some punctuation patterns entirely on the Mac. It saves only the reviewed style instructions through the existing style editor; it does not save or send the example text. It is a transparent heuristic, not a secretly trained model of your soul. A selected cloud cleanup provider receives the resulting instructions with future dictations.

## The pause contract

Automatic finish is **off by default**. Enable it in Settings → Dictation. Thoughtful mode waits 12 seconds of quiet, then gives you another 3 seconds. A few unfinished English endings get extra time. A short noise spike or silent startup does not arm it, and missing audio frames cannot complete the timer.

It applies to toggle-mode dictation, not command/edit modes or training. Speaking resets the countdown; clicking it disables automatic finish for that recording. Automatic finish never dispatches Send. There is no reliable way to infer “I am done thinking” from silence alone. We prefer admitting that to interrupting your next great idea with confidence.

## Measurements, with the footnotes still attached

| Metric | Evidence / limitation |
| --- | --- |
| **30.6× realtime** | Parakeet TDT v3; bundled 1.2-second sample; approximately 0.04s median of 3 warm runs; 16 GB, 10-core Apple Silicon Mac; Sept 11, 2026. Not an accuracy benchmark or a prediction for all recordings. |
| **12 templates** | Implemented prompt presets, alongside custom and personal styles. |
| **3 overlay positions** | MacBook notch, screen edge, and near the typing cursor. AX support determines caret placement. |
| **8s / 30s** | Dictation cleanup warning / original-words fallback thresholds, not advertised latency targets. |
| **407 selected tests** | Current local regression target, including pause behavior, late-result suppression, personal-style sample privacy, diagnostic opt-in, and existing dictation/provider/shortcut coverage. See the dated review for the completed run. |
| **Live insertion + undo** | TextEdit: inserted at the cursor, appended more text, undid only the insertion. Other apps need their own checks. |

There are no invented “99.9% accuracy” claims here. The spreadsheet was devastated.

## Existing capabilities retained

- Speech model library/downloads; Whisper, Parakeet and other upstream-supported engines, subject to hardware/model compatibility.
- Configurable API and local-server cleanup providers, including compatible OpenAI-style endpoints. API usage is billed by the provider; a chat subscription does not automatically include API credits.
- Custom shortcuts, per-app prompt routing, manual text insertion, dictionary learning, vocabulary boosts, punctuation rules, file transcription, history, and original command/edit capabilities.
- Native blue/ink surfaces, Liquid Glass where supported, reduced-motion handling, compact notch/cursor indicators, and responsive list/detail layouts.
- Microphone/Accessibility setup and a draggable copy of the **actual running app** in the floating permission helper.

The private Fluid Intelligence runtime is not present in the upstream public source. Its conditional integration remains; local cleanup through configured local servers is separate. No claim is made that every available model or paid endpoint has been live-tested.

## Privacy, in plain words

On-device speech processing works locally after downloading a compatible model. Cloud services receive the content needed for the service you choose. History and audio storage are separate settings. Detailed diagnostics are now explicitly opt-in, off by default; they can contain dictated text and app context. Common credential patterns are redacted, but review logs before sharing. Older log files are not silently erased.

Personal-style examples stay in the editor’s memory and are cleared after creating a draft. VOCA does not install a passive typing collector for this feature. The inherited telemetry configuration is disabled in this preview. Website illustrations do not request a microphone and the site has no analytics.

## Repository map

```text
VocaSource/        Active Swift/SwiftUI/AppKit app, original notices and tests
VocaSource/scripts/ Build, package, and selected regression runner
index.html        Product website
styles.css        Website presentation
app.js            Accessible demo and website interactions
config.js         Preview / checkout / download / support configuration
public/assets/    Website assets and font notices
scripts/          Read-only release gates
 docs/            Release, monetization, and product notes
```

Compiled apps, retired prototypes, downloaded models, user recordings, local databases, credentials, signing keys, and DerivedData are intentionally excluded. Your private repository is not a 12-gigabyte scrapbook of Xcode’s feelings.

## Build the Mac app

Use Xcode with the macOS 26 SDK. The app deployment target is macOS 15; native Liquid Glass is conditional on macOS 26. The current live checks were on Apple Silicon/macOS 26.4.1. Intel and macOS 15 require release testing.

```sh
xcodebuild -downloadComponent MetalToolchain
cd VocaSource
./build-voca.sh
./scripts/test-voca.sh
```

Swift packages download on a clean build. `VOCA_PACKAGE_CACHE` can point to an existing package checkout cache. The product remains `../VOCA.app`; internal Xcode scheme/module names retain their upstream names to avoid destabilizing the implementation.

Local packages use an ad-hoc signature. Rebuilding can invalidate Accessibility/Microphone registrations. The permission helper points to the running build. Public releases require your own Developer ID identity:

```sh
VOCA_BUILD_CONFIGURATION=Release \
SIGNING_IDENTITY='Developer ID Application: YOUR VERIFIED IDENTITY' \
./build-voca.sh
```

That command signs; it does **not** notarize or certify redistribution rights. Release signing uses the hardened runtime and a separate reduced entitlement file. Validate it with your actual identity and pinned dependencies before shipping.

The selected test runner excludes the inherited nondeterministic Whisper Tiny fixture test and does not call paid APIs. Tests are not a substitute for live Word/browser insertion, noisy-room finishing, microphone switching, upgrade permissions, and multi-display checks.

## Build the website

```sh
npm run dev       # local preview, normally http://localhost:5173
npm run check
npm run build     # static output in dist/
```

No npm dependencies. Node 20 or newer. `releaseReady: false` deliberately prevents checkout and download links from activating. Set real URLs, support details, and final seller terms only after the release checklist passes. The €49 one-time price is a proposal, not a live offer. Cloud usage is separate.

```sh
node scripts/site-release-check.mjs
./scripts/release-check.sh VOCA.app
```

A blocked release check is the expected result for an ad-hoc preview. We do not turn the test green by renaming “blocked” to “premium early access.”

## License and business model

The application is GPLv3; see [LICENSE](LICENSE), [original source documentation](VocaSource/README-UPSTREAM.md), [changes](VocaSource/VOCA-CHANGES.md), and [third-party notices](VocaSource/THIRD-PARTY-NOTICES.txt). Third-party fonts, models, and assets retain their own terms.

A paid download, maintained installer, updates, and support can be monetized while preserving GPL rights. A private development repo is fine; distributing binaries creates corresponding-source obligations to recipients. A closed-source/no-redistribution EULA is not compatible with this fork without separate permissions.

See [monetization and license plan](docs/MONETIZATION.md) for checkout, purchase keys, and source delivery. No payment service, activation server, or paid entitlement is secretly “implemented” as a button that always says success.

## Before you publish

Read [release readiness](docs/RELEASE-READINESS.md) and [the current application review](VocaSource/VOCA-PERSONAL-REVIEW.md). The important remaining work is stable signing/notarization, dependency/model rights, supported-device live tests, and real support/checkout infrastructure. Then a small beta. Then sales.

Beautiful buttons are nice. A customer’s words arriving intact is the business.

## Private development repository

[InstinctEx/VOCA](https://github.com/InstinctEx/VOCA) contains the source snapshot, website, tests and these documents. Repository visibility is private. The original website workspace remote was preserved; the upload checkout is `.release-repo/`. Do not include build caches, recordings or credentials when updating it.
