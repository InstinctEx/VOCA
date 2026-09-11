# VOCA appearance review

September 11, 2026. Implemented using the supplied Apple-design guidance and the design-system skill.

## Summary

VOCA is a macOS dictation utility. Its configuration window helps people choose a voice engine, tune their words, and return to writing. The notch and destination icon remain its signature; the window should be quiet enough to support that interaction.

The previous purple accent and gray content backdrop competed with the requested native character. The detail view also painted the system window background over the custom theme. This update uses native adaptive blue for actions, custom ink-blue dark surfaces, and soft-white light surfaces. Ink blue is a design judgment for VOCA, not an Apple-prescribed dark-mode color.

## Improvements implemented

- Corrected theme propagation and the detail background so the selected palette reaches the actual content canvas.
- Removed decorative glass title tiles. Titles use the system face at 30 pt bold; descriptions use 14 pt. Reading panels are opaque, with continuous corners and quiet borders.
- Reserved native glass for navigation and controls. Shared glass surfaces have opaque alternatives under Reduce Transparency or Increase Contrast. Increased Contrast also strengthens panel borders.
- Kept unselected navigation icons neutral. Used system blue for actions and system green for success, with text and symbols communicating status as well.
- Set blue as the default accent with a one-time migration. Optional accent and appearance choices remain available because the user asked to preserve settings. System appearance remains the default for new preferences.
- Changed the notch waveform to white. Existing opening, contraction, and Reduce Motion behavior are retained.

## Color and typography

| Role | Light | Dark |
| --- | --- | --- |
| Canvas | #F5F7FA | #0D1521 |
| Content panel | #FFFFFF | #172333 |
| Raised surface | #FFFFFF | #213247 |
| Secondary text | #536276 | #ABBDD1 |
| Metadata | #606D80 | #8DA0B8 |
| Action | NSColor.systemBlue | NSColor.systemBlue |

Computed WCAG contrast for these opaque pairs: secondary text on the main panel is 6.22:1 light and 8.25:1 dark. Metadata is 5.25:1 light and 5.93:1 dark; metadata on raised dark panels is 4.87:1. Primary text remains the semantic system label color. These figures do not certify all native controls or translucent combinations.

The type scale is 30 pt page titles, 15 pt section titles, 13–14 pt body and control text, and 12 pt secondary metadata. Shortcut labels use the system monospaced face. Library rows keep their controls next to the model they affect.

## Layout and craft

One sidebar supports a scrollable content column, capped at 900 pt, with 32 pt outer padding and 24–28 pt section gaps.

```text
Regular                         Compact
┌──────────┬──────────────────┐ ┌─────────┬───────────────┐
│ Search   │ Title   Shortcut │ │ Search  │ Title Shortcut│
│ Overview │ Readiness panel  │ │ Pages   │ Readiness     │
│ Configure│ Three shortcuts  │ │         │ Shortcuts     │
│ Activity │ Practice editor  │ │         │ Practice      │
│ Settings │                  │ │ Settings│      ↕       │
└──────────┴──────────────────┘ └─────────┴───────────────┘
```

The element removed in the final critique was the decorative title icon tile. It repeated the navigation icon without helping the task. Navigation cards reserve equal title and description space so wrapping at a narrower width does not produce uneven cards. No new ornamental animation was added.

## Validation and limits

The macOS app builds and packages successfully. Both appearances and a narrower window were inspected in the running app; the speech model library was also checked in dark appearance. Contrast was calculated from the explicit opaque color pairs above. Native controls and the existing data/action bindings remain in place.

This pass does not claim a complete VoiceOver, maximum text-size, or earlier-macOS audit. Accessibility material fallbacks were inspected in code; system accessibility preferences were not changed for this check. Speech recognition and provider requests were not exercised as part of this appearance pass.

## Apple references

- [Color](https://developer.apple.com/design/human-interface-guidelines/color): semantic system colors and paired custom appearances.
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials): Liquid Glass belongs in navigation and controls, with standard surfaces for content.
- [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode): check both appearances and preserve legibility.
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography): platform typography and readable hierarchy.
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): contrast and alternatives to visual effects.

The pasted repository-maintenance AGENTS document describes a separate skill repository; its package-maintenance commands do not apply to this Swift application. Its requirements to ground design decisions and distinguish guidance from judgment informed this review.
