# KOReader Mods

A collection of patches and style tweaks for [KOReader](https://github.com/koreader/koreader).

## Patches

User patches go in the KOReader `patches/` directory. Copy the `.lua` file and restart KOReader.

| Patch | Description |
|-------|-------------|
| [2-suppress-opening-dialog.lua](patches/2-suppress-opening-dialog.lua) | Hides the "Opening file '...'" dialog that briefly flashes when opening a book. |
| [2-coverbrowser-swipe-updown.lua](patches/2-coverbrowser-swipe-updown.lua) | Adds up/down swipe for page navigation in CoverBrowser History/Collections views. |
| [2-suppress-frontlight-notifications.lua](patches/2-suppress-frontlight-notifications.lua) | Suppresses "Frontlight intensity set to X" and "Warmth set to X" notifications when using gestures to change brightness/warmth. |

Also see [bookends.koplugin](https://github.com/AndyHazz/bookends.koplugin) — configurable text overlays at 6 screen positions.

## Style Tweaks

CSS style tweaks go in the KOReader `styletweaks/` directory. Each `.css` file is automatically loaded and applied to documents.

| Tweak | Description |
|-------|-------------|
| [captions.css](styletweaks/captions.css) | Caption styling |
| [footnotes.css](styletweaks/footnotes.css) | Footnote formatting |
| [headings.css](styletweaks/headings.css) | Heading styles |
| [hr.css](styletweaks/hr.css) | Horizontal rule styling |
| [img.css](styletweaks/img.css) | Centre images, constrain to page width |
| [paragraphs.css](styletweaks/paragraphs.css) | Paragraph spacing and indentation |
| [tables.css](styletweaks/tables.css) | Table formatting |
| [toc.css](styletweaks/toc.css) | Table of contents styling |

## Installation paths

| Device | Patches | Style Tweaks |
|--------|---------|--------------|
| Kindle | `/mnt/us/koreader/patches/` | `/mnt/us/koreader/styletweaks/` |
| Kobo | `/mnt/onboard/.adds/koreader/patches/` | `/mnt/onboard/.adds/koreader/styletweaks/` |
| Android | Varies | Same |

## Compatibility

Tested on KOReader 2025.08 (Kindle PW5).

## License

AGPL-3.0 — see [LICENSE](LICENSE)
