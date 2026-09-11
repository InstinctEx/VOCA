# VOCA

A UI and branding fork of the original FluidVoice public source, commit `42e33e68ec473129ad090521e56c22c912a16db3`.

The active code is here in **VocaSource**. The prior VocaNative reimplementation is retired. The packaged app is `../VOCA.app`.

The original speech models, model downloads, AI/API providers, enhancement, shortcuts, automatic insertion, compact overlays, dictionary, file transcription, history, and settings are retained. UI additions include a VOCA waveform mark, refined shared theme and icons, and live feature search (try “models”, “API”, or “fixer”).

## Everyday controls

- **⌘K** opens Quick Controls for the installed speech model, microphone, and writing style. Tab and arrow keys work with the native controls.
- **Settings → Dictation → Check permissions & insertion** verifies a disposable draft in a chosen running app. The check never submits the draft.
- **Last insertion & recovery** can undo a verified insertion while preserving later appends. It refuses uncertain edits and keeps the dictated words available to copy.
- **Settings → Overlay → Near the Typing Cursor** places a compact destination-icon pill beside the caret when the app exposes its position. The screen-edge fallback remains available.
- **Speech Models → Find a model for this Mac** measures local compute capacity and recommends a starting model. **Time selected model** measures the installed local model against the bundled sample.
- Writing Styles has Natural, Concise, Email, and Notes templates plus advanced prompt editing. History adapts to a list/detail flow in narrow windows. Usage leads with time saved and recent trends.

See **VOCA-WORKFLOW-REVIEW.md** for the current implementation and verification details.

## Build

Run `./build-voca.sh` with Xcode installed. It builds the public target and packages `../VOCA.app`. A local ad-hoc signature is used unless `SIGNING_IDENTITY` names an installed signing identity. Ad-hoc rebuilds may require macOS permission approval again. The app needs Microphone and Accessibility access; API providers need your own credentials.

400 selected regression tests passed across shortcuts, navigation, native editing, providers, dictionaries, history/routing, audio conversion, and privacy boundaries. This is not a claim that every downloadable model or paid API has been live-tested.

The private Fluid Intelligence runtime is absent from the upstream public repository. Its conditional integration is retained. VOCA updates require an independent release channel; upstream updates cannot overwrite this fork.

## License and provenance

GPLv3; see LICENSE. Original author credits are preserved. See README-UPSTREAM.md for the original project's documentation and VOCA-CHANGES.md for this fork's scope.

See **VOCA-REVIEW.md** for the September 2026 application review, release blockers, and verification limits. **THIRD-PARTY-NOTICES.txt** inventories the Xcode-locked dependencies; mediaremote-adapter still requires licensing clarification before distribution.

## Personal voice preview

The new Sounds like me card creates a reviewed personal prompt from writing samples analyzed locally. Twelve templates are available. Optional Finish after a pause appears in Dictation settings. Slow dictation cleanup warns at eight seconds and falls back at thirty seconds; Quick Controls offers the original words immediately. Detailed diagnostics are now off by default. See [VOCA-PERSONAL-REVIEW.md](VOCA-PERSONAL-REVIEW.md) and the repository-level [release checklist](../docs/RELEASE-READINESS.md).
