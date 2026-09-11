# VOCA launch drafts

Prepared September 12, 2026. Drafts only—not posted. The repository is currently private, public downloads and checkout are not live, and the beta is not Apple-notarized. Do not attach the private GitHub link as a public download. Add a verified public demo link if available, and check the community's current self-promotion rules before posting.

## r/macapps

**Title:** I'm building VOCA: local Mac dictation with Qwen cleanup and room to think

Hey everyone — I'm the developer working on VOCA, a native Mac dictation app. Yes, another one. Apparently my keyboard hadn't suffered enough competition.

It's based on FluidVoice's GPLv3 foundation, with a redesigned interface and a workflow I've been shaping around the way I actually write:

- Dictation into the app you're using, with a compact waveform and destination icon.
- Local speech models plus optional Qwen 4B cleanup on Apple Silicon. No API key needed for the local setup.
- Twelve editable writing styles and custom prompts.
- Optional automatic finish that waits through a pause, then gives you a countdown. Thinking is allowed.
- Original-word recovery when cleanup fails or takes too long.

The app ZIP is now about 20 MB; speech models and the roughly 2.28 GB Qwen model download separately.

It's still a beta. Public downloads aren't live yet, and it isn't Apple-notarized, so installation will involve manual approval. I'm considering free source access with a €5 prebuilt download that includes all local features, rather than a subscription or paywall on writing styles. Cloud API usage would remain separate.

What frustrates you most about Mac dictation today: accuracy, latency, language switching, or editing what it inserts? I'd appreciate honest feedback before opening the beta.

## LinkedIn

I've been building VOCA, a native Mac dictation app, around a simple goal: make speaking feel like a natural part of writing.

It builds on FluidVoice's GPLv3 foundation, with a redesigned interface, local Qwen cleanup, editable writing styles, and a compact recording indicator that shows where your words are going.

Some of the most useful work has been in the less glamorous details: giving people time to think before auto-finish, preserving original words when AI cleanup fails, and preventing cleanup from answering a dictated request instead of editing it.

The latest beta has 414 passing app regression tests. I also reduced the download from 27 MiB to about 20 MiB without removing features; models download separately. Those checks are progress, not a substitute for testing with real users.

I'm exploring a €5 prebuilt download with all local features included and free source access. No subscription for local dictation. Optional cloud API costs would be separate.

It's still a locally signed, unnotarized beta, with public downloads not yet open. I'd love to hear from Mac users: where would dictation genuinely save you time, and what makes you stop using it?

#macOS #IndieDevelopment #LocalAI
