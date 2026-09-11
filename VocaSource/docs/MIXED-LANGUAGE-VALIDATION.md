# English–Greek transitions and cursor pill

The reported phrase was tested in two stages, with installed Parakeet v3 and Qwen3 4B. Fixtures are synthetic macOS Samantha and Melina speech, not recordings of the user.

## Diagnosis

- Qwen preserved the user's mixed English/Greek text before changes.
- Parakeet recognized each synthesized sentence independently.
- With the two speech samples concatenated without an added pause, Parakeet returned only “This is a test in English.”
- NVIDIA explicitly describes v3 as not fully tuned for code switching: https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3/discussions/1

## Mitigation and limits

“Switch languages at pauses” in Speech Models defaults on for Parakeet v3. Final decoding uses separate phrases at sustained quiet (at least 320 ms, amplitude-dependent). A half-second pause worked in the fixture: “This is a test in English. Αυτό είναι ένα τεστ στα ελληνικά”. Qwen cleanup preserved both sentences afterward.

All input samples are retained. Tiny pauses do not trigger splits. Decoding uses the base manager for these phrases to avoid language-specific vocabulary rescoring; normal unsplit decoding retains vocabulary boosting. This can trade some sentence-level context and extra decoding calls for better language transitions. It is not language detection, model retraining, or a guarantee for uninterrupted switching. Noise can prevent quiet detection. Live streaming previews still use the existing decoder; this change targets the final inserted transcript.

Local cleanup now rejects loss of an entire Greek/Latin script span. This is deliberately a limited guard, not proof that meaning or every word is preserved.

## Pill

Above-right is preferred; above-left, below-right, below-left, and lateral placements follow depending on display space. The AX caret is refreshed every 400 ms. Failed reads clear the old anchor and use the text-field perimeter; if neither is exposed, the pill moves to the upper-right display edge rather than the text area's center. The captured destination remains unchanged.

Geometry tests cover right/top edges, limited vertical space, changing caret locations, and displays with negative coordinates. Real cross-app AX behavior still depends on the destination exposing accurate caret bounds; no pointer location is represented as a known text caret.

## Reproduce

Run `scripts/test-mixed-languages.sh` with Parakeet v3, VOCA Polish, and the Samantha/Melina system voices installed. Set `VOCA_PACKAGE_CACHE` as needed. The script generates synthetic audio in `/tmp` and opts into the bilingual integration test. Set `TEST_RUNNER_VOCA_TEST_LOCAL_LLM=1` to include the broader real Qwen smoke suite (numbers, Greek, cancellation, and ASR coexistence).
