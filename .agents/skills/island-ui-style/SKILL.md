---
name: island-ui-style
description: Preserve the established Sarıyer Dynamic Island visual style when designing or editing its panels, icons, controls, and transitions. Also use when the user explicitly requests this style for another interface. The separate settings window is not an approved style reference.
---

# Island UI style

Apply the user's established island design, developed through their feedback. Extend the existing visual language instead of introducing a new design system. Their latest explicit request takes precedence over these defaults.

## Scope and references

The approved reference is the main island: Prayer, Player, Calendar, and Focus in compact, expanded, and notification states. The user likes this style; the newly created macOS-inspired settings window is **excluded**. Do not use its sidebar, grouped cards, or window chrome as the island's design language. Styling settings is a separate design task.

For the current implementation, see [references/current-project.md](references/current-project.md). Read it when modifying this project; otherwise the design rules below are self-contained.

## Surface and composition

- Use one opaque black surface, centered at the monitor's top edge. Top shoulders curve out into the screen edge; bottom corners are generously rounded. Avoid a floating oval as an intermediate shape.
- Compact, expanded, and notification presentations are states of the **same resizing panel**. Do not stack independent black panels, replace windows mid-transition, or expose a blank gap between states.
- Keep controls and information comfortably spaced but compact. Different panels have their own useful dimensions. Center the surface as its width changes, and keep content centered inside the animated bounds.
- Use a small row of outline panel icons at the upper left. Make the selected icon unmistakable with a subdued rounded charcoal highlight and brighter glyph. The upper right contains a pin for the default panel and a settings gear. Hide navigation and preference controls in notifications.
- Keep the interior open. Do not add decorative cards, a visible grid, cross dividers, heavy outlines, or an extra background behind the preset choices. A 2×2 arrangement can use spacing alone.

## Color and typography

- White primary content, soft gray secondary content, near-black tracks. Use the Windows-selected system accent/secondary color for restrained highlights; do not introduce a fixed green or decorative palette.
- Player audio bars can take their color from album art. Active break controls, inner rings, and break time are orange. Timer time becomes red in the final 10% of the main countdown. These are intentional semantic exceptions.
- Use Segoe UI or the existing platform font. Prefer normal or medium weight; reserve semibold for an active prayer or a small amount of emphasis. Avoid heavy labels and oversized headings.
- Typical logical sizes: compact information 12–13, secondary labels 10–12, expanded body 14, timer preset numbers 22 with light weight, centered countdown 26 inside the ring. Adapt to actual fit and DPI rather than treating these as universal fixed values.
- Align names, artwork, numbers, and controls optically, not only by their layout rectangles. The timer name needed a slight upward adjustment to look vertically centered.

## Icons and controls

- Use consistent, thin, rounded outline geometry at approximately 16–20 logical pixels. Prefer vector icons over Unicode symbols, which can look mismatched or tiny. Player transport icons should be recognizable filled previous/play/pause/next shapes.
- Do not show hover tooltip text anywhere in the island. Preserve accessible names separately.
- Prefer direct interaction over extra buttons: click a countdown to start/pause; click a preset to start immediately; use a discreet right-side arrow to start a custom time.
- Editable timer name: centered, softly rounded field, faint system-color fill at roughly 12% opacity, medium-weight text, no pencil. Fit the field to the text with comfortable horizontal inset; the current implementation uses a 56–200 logical-pixel width range.
- Limit names by rendered width as well as a reasonable character cap. Reject overflowing typing/paste without losing accepted text. A quick, small left-right shake communicates the limit; do not add an error dialog. Current shake is about 224 ms, amplitude 4 px, returning to zero.
- Custom timer entry uses three compact h / min / s fields. Remember the last valid custom duration and leave it editable. Keep all choices within the panel's bounds.

## Presentation patterns

- **Prayer:** clean label/time rows; highlight the current period's name and time in system accent with slightly stronger weight. Include Islamic midnight and last-third start. The folded last-third period runs until Fajr.
- **Player:** centered square-cropped artwork, title and artist, small audio-reactive bars, thin seek track, clean transport icons. Compact uses small circular art and sound bars. Keep the timeline and remaining-time label clipped inside the panel during every resize.
- **Focus idle:** centered editable name; spacious 2×2 presets 5 / 15 / 30 / 60; custom fields below. No countdown ring until a session starts.
- **Focus active:** choices disappear; a large circular countdown takes their place, time centered within it. Pause retains the ring and resume interaction. Reset/finish restores the choices. The remaining-time ring starts full and ends empty, with smooth proportional movement and exact endpoints.
- **Focus compact:** larger outer ring on the left, timer name beside it, Break/Resume beneath the name, remaining time on the right. During a break, freeze the main ring and count five minutes in a smaller orange inner ring; show break time in orange on the right. Resume the main timer afterward.
- **Notifications:** show the relevant event or song without panel-switching or default-setting controls. Keep content replacements stable rather than blanking the whole surface.

## Motion and continuity

- Reshape the same surface with a smooth eased width/height animation. Current baseline is approximately 400 ms, not a snap or an exaggerated slow flourish.
- On the desktop, compact remains visible. Over apps, temporary panels enter from the screen's top edge and fully exit upward; do not collapse them into a stranded oval.
- Keep outgoing/incoming content inside the animated silhouette. Use a brief soft blur/dissolve for information changes; avoid visible text traveling outside the panel, delayed compact content, or restarting animation when clicking the already-selected tab.
- Keep internal choices/ring transitions subtle, roughly 180–220 ms. A notification receiving new song metadata updates in place and restarts its display timer rather than closing and reopening.
- Animate progress with a linear time-based ratio, not repeated ease-in/out or arbitrary oscillation. Pause/break must actually pause progress. Preserve the countdown through folding, tab changes, sleep, and restart.

## Review before delivery

Inspect the changed state at its real panel size, including compact and mid-resize when relevant. Check centered alignment, readable contrast, exact progress endpoints, stable clipping, and keyboard editing. Preserve existing timer/media behavior while changing appearance. For new visual directions, respect whether the user requested a preview or authorized deployment; this skill itself does not authorize running, publishing, or pushing anything.
