# VOCA unsigned beta

This download is an optimized macOS development build, locally signed but **not signed with an Apple Developer ID or notarized by Apple**. It is a beta, not a certified production release. Use only a download whose origin you trust.

1. Unzip VOCA-beta.zip and move VOCA.app to Applications. Keep only one installed copy.
2. Open it. If macOS blocks it as unidentified/unverified, inspect the warning. For a trusted copy, Apple's supported flow is System Settings → Privacy & Security → Open Anyway, then confirm. Do not disable Gatekeeper or run quarantine-removal commands. Do not override a malware or damaged-app warning; stop and contact the distributor.
3. Grant Microphone and Accessibility when requested. Apple Speech also needs Speech Recognition. Use VOCA's destination checker before real work.
4. Download a speech model. VOCA Polish's Qwen model is downloaded separately. Local processing works offline after downloads; cloud providers require your own account and may charge separately.
5. Music/Spotify pause is optional. Open the player, then use Allow Music / Allow Spotify in VOCA settings. Other media players and browser tabs are not controlled.

Ad-hoc updates may require re-enabling VOCA in Accessibility. The current beta targets Apple Silicon, macOS 15 or newer; testing is on macOS 26.4.1. The broader hardware/app matrix remains unverified. Keep important text recoverable and report the destination app, macOS version, model, and reproducible steps with a bug report; do not include API keys or private dictation.

The matching VOCA-source.zip, SOURCE-REVISION.txt and SHA256SUMS belong beside this binary. Verify checksums with `shasum -a 256 -c SHA256SUMS`. Source users need Xcode and the pinned dependencies to build; model weights are not included. GPLv3 rights apply equally to free and paid copies.

Apple's installation guidance: https://support.apple.com/en-us/102445

Hosting note: keep the website in Cloudflare Pages, but host any ZIP over 25 MiB on suitable download storage (for example R2). Pages has a 25 MiB per-file limit: https://developers.cloudflare.com/pages/platform/limits/
