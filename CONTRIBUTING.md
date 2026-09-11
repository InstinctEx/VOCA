# Contributing to VOCA

Thanks for helping make dictation less work. VOCA is a public beta, built on FluidVoice under GPLv3.

## Report a bug

Open an issue at https://github.com/InstinctEx/VOCA/issues. Include your macOS version, Mac chip/memory, app version or commit, selected speech model and cleanup provider, destination app, and steps to reproduce. Explain what you expected and what happened.

Use made-up text to reproduce dictation problems. Never post API keys, personal recordings, private prompts, customer text, or an unreviewed diagnostic export. An issue is public, even if the screenshot feels small.

For security-sensitive reports, use GitHub's private vulnerability reporting if available. Otherwise open a minimal issue asking for a private contact without exploit details or private data.

## Make a change

1. Fork and clone the repository; create a focused branch.
2. Follow the build instructions in the root README. App work lives in `VocaSource/`; the website lives at the repository root.
3. Keep existing dictation, permission, recovery, and offline behavior intact. Respect Reduce Motion and accessibility labels for UI work.
4. Run relevant tests. Website: `npm test && npm run check && npm run build`. App: `VocaSource/scripts/test-voca.sh` with the required Xcode tooling.
5. Submit a pull request explaining the problem, resulting behavior, and what you tested. Include UI screenshots when helpful.

Do not commit app bundles, model weights, recordings, build caches, personal Xcode settings, or credentials. Preserve copyright and third-party notices. Contributions are made under the repository's GPLv3 licence; you must have the right to submit them.

A passing test suite is useful evidence, not a promise that every speech model or destination app has been verified. Be specific about what you tried.
