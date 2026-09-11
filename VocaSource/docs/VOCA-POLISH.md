# VOCA Polish

VOCA's built-in text enhancement engine runs Qwen3-4B-Instruct-2507, quantized to 4 bits, through MLX Swift on Apple Silicon. No Python, Ollama, LM Studio, API key, or local HTTP server is required. The existing external providers remain available.

## Use

Open **Text Enhancement → VOCA Polish · On this Mac**. Download and verify the model, then choose it as the enhancement provider. Writing-style prompts—including reviewed personal styles—are supplied to the local editor. **Try it on your words** runs a synthetic or user-entered sample inside Settings and reports elapsed time; it never inserts the sample into another app.

The initial download is approximately 2.28 GB. Pause/resume retains partial bytes and completed files. Every artifact is pinned to repository revision `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b` and checked against its expected size and SHA-256 before installation. A cross-process lock prevents two VOCA instances from downloading into the same folder. Invalid files are rejected and downloaded again.

Files live in `~/Library/Application Support/VOCA/Polish/qwen3-4b-instruct-2507-4bit`. Delete model removes downloaded weights/tokenizer files; writing styles remain. This directory is never part of the source upload.

## Runtime behavior

- Apple Silicon; at least 8 GB physical memory, 16 GB recommended when running speech recognition alongside the model.
- Weights are retained for one idle minute, or up to ten minutes with **Keep ready between dictations**. Memory-pressure notifications request release; active inference finishes/cancels before the model is released.
- Model requests are serialized. Another request receives an explicit busy error rather than sharing mutable generation state.
- Each request starts fresh. Conversation context and transcript KV caches are not retained between dictations.
- Local generation uses greedy decoding, an 8,192-token upper context limit, and up to 2,048 output tokens. The existing dictation budget may impose a smaller limit. Oversized input produces an actionable error instead of silent truncation.
- Incomplete output, internal reasoning/control tokens, empty results, or changed numeric facts trigger original-word recovery. This is conservative: converting a spelled-out number to digits or adding numbered lists may be rejected. It is not a proof that every name, negation, or meaning was preserved.
- Cancellation is checked during generation. The existing 30-second dictation deadline prevents a late second insertion. An individual GPU operation/model load may take time to finish before resources are released.
- The engine currently serves dictation enhancement and the existing local rewrite bridge; it is not exposed as a general agent/tool-execution model. No tools or network actions are granted to the model.

## Privacy and licensing

Downloading contacts Hugging Face/CDN servers. After installation, tokenizer and model loading use local files; text inference makes no API request. Ordinary VOCA history and explicitly enabled detailed diagnostics retain their existing behavior—offline does not mean “never stored.”

The Qwen base model is Apache-2.0; the MLX runtime libraries are MIT. Notices are preserved under `docs/licenses` and in the packaged third-party notice file. VOCA remains a GPL FluidVoice fork; these additions do not change that license. Existing signing/notarization and unrelated dependency release blockers remain.

## Validation

Regression tests cover artifact hashes, resumed HTTP range validation, routing, numeric/incomplete-output guards, and writing-style prompt construction. Opt-in real-model testing uses `TEST_RUNNER_VOCA_TEST_LOCAL_LLM=1` with `scripts/test-voca.sh` after the verified download. It exercises English/Greek cleanup, negation, cancellation and next-request recovery, explicit unload, and speech-model coexistence when an installed speech model is selected.

Latency depends on text length, available memory, model warmth, and concurrent work. Do not publish a universal speed or accuracy promise from the small synthetic test set.

### Local validation — 11 September 2026

Test machine: Apple Silicon MacBook Pro, 10 CPU cores, 16 GB memory, macOS 26.4.1. The installed 2.28 GB model passed SHA-256 verification, including a resumed transfer of the final weight-file segment. A file-growth regression test covers stale filesystem metadata during resume.

Builds require Xcode's Metal toolchain (`xcodebuild -downloadComponent MetalToolchain`). MLX's compiled Metal library is embedded in the packaged app.

Final selected run: **407 passed, 0 failed, 0 skipped**, including real local inference, cancellation/recovery and explicit unload. First English cleanup took 6.36 s; Greek cleanup 4.68 s; a short English cleanup with Parakeet loaded took 1.73 s. These are synthetic samples from a Debug build, not product-wide benchmarks. The tests caught and corrected numeric-formatting and language-instruction ambiguities before packaging.

Saved API keys are read only after the explicit Unlock action on a cold launch. Local cleanup does not require unlocking them. After unlocking, cached access and ordinary key updates continue normally. This avoids a legacy Keychain ACL prompt blocking startup after a development rebuild.
