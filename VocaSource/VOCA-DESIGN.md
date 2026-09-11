# VOCA interface language

The interface is a quiet macOS utility: plain system typography, an adaptive native blue accent, and one clear task on each page.

## Shared components

- VocaPageHeader: 30 pt bold title and 14 pt secondary description. No decorative glass tile.
- VocaContentSurface: continuous 20 pt corners, opaque ink or white background, subtle separator stroke. Content panels do not scale on hover.
- VocaSectionHeading: 15 pt semibold title and optional secondary count.
- Native glass buttons: macOS 26 glass and glassProminent, with bordered alternatives on earlier systems.
- Pages: 32 pt outer padding, 24–28 pt section spacing, 900 pt maximum reading width.

## Patterns

Overview presents readiness and a shortcut; setup actions remain available. Libraries put search before rows and keep actions visible. Detail sheets do not change the active model. Editors lead with the user's content, with provider and shortcut configuration available through disclosure. Dictionary tabs keep separate tasks separate.

## Accessibility and behavior

Use native text fields, buttons, pickers, disclosure groups, and sheets for keyboard and VoiceOver support. Decorative symbols are hidden from accessibility. Disabled actions remain tied to the original readiness conditions. Glass falls back to opaque raised surfaces when Reduce Transparency or Increase Contrast is enabled. Notch opening and contraction respect Reduce Motion. Dictation, downloads, providers, phrase persistence, and shortcut routing continue through the existing services.

## Ink and blue palette

Native blue comes from NSColor.systemBlue, not a copied RGB value. Content surfaces are paired: canvas #F5F7FA / #0D1521, panel #FFFFFF / #172333, raised #FFFFFF / #213247. Secondary text #536276 / #ABBDD1; metadata #606D80 / #8DA0B8. Primary text uses the system label color. On the main panels secondary contrast is 6.22:1 light and 8.25:1 dark; metadata is 5.25:1 and 5.93:1. On raised dark surfaces metadata is 4.87:1. These are computed opaque-color pairs, not a blanket certification of every native control.

The notch remains the signature: black camera surround, white audio-reactive bars, destination app icon, reversible expansion. The rest of the app supports quiet reading and fast configuration. System appearance remains the default; existing explicit appearance choices stay available.


### Workflow components (September 2026)

- **Preference row:** a leading label with a native trailing switch. Brief descriptions wrap; longer explanations open from an accessible info button. Status and errors remain visible. Secondary groups expand automatically for Settings search.
- **Phrase library:** searchable, inline editable rows. Creation is a separate collapsible composer. Training uses three quiet sample segments rather than a score ring.
- **Writing template:** a balanced two-column grid with an outlined selection. Choosing a template explicitly replaces draft instructions; advanced editing preserves the original prompt model and provider routing.
- **Quick Controls:** Command-K, native keyboard-focusable pickers, Escape to close. No model or input changes while capture/preparation is busy.
- **Cursor pill:** 148-point compact content with destination icon and waveform. No transcript expansion in cursor mode. Top/bottom/side geometry avoids the caret and display edges; the original notch and bottom options remain available.
- **History:** below 720 points of detail-column width, switch from split view to list → detail with a visible back button. Selecting another page preserves stored history.
- **Usage:** one time-saved summary, activity trend, adaptive supporting metrics, collapsed milestones. Estimates disclose the chosen typing-speed baseline.
