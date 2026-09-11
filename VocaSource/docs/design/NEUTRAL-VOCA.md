# VOCA interface — neutral surfaces

September 2026 design pass. References supplied by the product owner informed grouped provider choices, compact navigation, and a light content canvas. No competitor branding or billing flows were copied.

## Visual language

- Warm white light appearance; neutral graphite dark appearance. Blue is reserved for selected controls and primary actions.
- Shared waveform mark for VOCA navigation and the built-in local enhancement provider. Third-party provider marks remain attributable to their services.
- Native SF typography, restrained page headings, 14-point panel corners and subtle separators.
- Liquid Glass remains on interactive controls and window chrome; large reading surfaces stay opaque and quiet. Existing Reduce Transparency, Increase Contrast and Reduce Motion behavior remains in place.

## Organization

- Text Enhancement separates On this Mac, Cloud services, and Your server. Verified and available connections stay within the selected category. Custom endpoints remain in Your server.
- Keychain controls appear only where external services need them. Performance information is progressively disclosed.
- Speech Models shows a compact current-engine summary, searchable library with All models / Downloaded, and the existing source/sort controls. Hardware recommendation remains available below the library.
- Overview uses quieter destination tiles, a clear dictation shortcut, setup checks, and the existing practice editor.
- Dictionary, styles, history and settings inherit neutral surfaces and typography without changing their stored data or dictation behavior.

## Accessibility and behavior

Segmented controls use native keyboard and accessibility semantics. The provider category changes only the visible library, never the selected dictation provider. Model filtering never switches or deletes a model. Native window controls and established shortcut routing are retained.

## Dashboard and interaction follow-up

Overview now places retained-history metrics first: estimated time saved, total words, dictation count, today's words, current streak and a seven-day activity spark chart. Zero history displays zero saved time. Estimates disclose the user's typing speed and assumed 150 speaking WPM; inference processing time is not mislabeled as recording duration.

All disclosure labels use a full-width native button with an expanded/collapsed accessibility value, keyboard activation and Reduce Motion support. The same style is injected into the separately hosted Settings document.

Detail scroll-edge effects are disabled on macOS 26 and the detail viewport clips its contents, preventing the toolbar-area effect from obscuring page headings. The AppKit settings scroll view owns explicit zero content insets, avoiding automatic titlebar-inset duplication. Settings navigation includes descriptive subtitles, a VOCA header, and setup/help actions.
