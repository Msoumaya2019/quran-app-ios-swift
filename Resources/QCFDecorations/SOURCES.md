# QCF V4 companion decorations

These two unmodified font files are companion resources, not Quran page data.
They total 341,036 bytes. The 604 colored page fonts continue to be downloaded
on demand / through the existing Quran download service.

Publisher: Quranic Universal Library (Tarteel), original Quran typography from
King Fahd Quran Printing Complex. Attribution: Quran fonts provided by Quran Foundation;
QCF V4 companion ornaments and Surah Name V4 provided by QUL / Tarteel.

## Original files

- `quran-common.ttf`: https://static-cdn.tarteel.ai/qul/fonts/common/quran-common.ttf
  SHA-256 `63675d54764c3e0acd3875e191dc6f0af1339ddbd53a1df7fcebbaabebc918fa`.
- `surah-name-v4.ttf`: https://static-cdn.tarteel.ai/qul/fonts/surah-names/v4/surah-name-v4.ttf
  SHA-256 `026cfe8ac461531a7b1c8e4edd05ce3343f09e9c73447ff14c6bc93f3193d661`.

## Primary documentation / permitted integration

QUL's resource documentation explicitly describes downloading and shipping the
fonts in an application, including iOS, with matching ligatures. No font tables,
glyphs, names or color palettes have been edited.

- https://qul.tarteel.ai/resources/font/459 (common font)
- https://qul.tarteel.ai/resources/font/457 (Surah Name V4; `surah001`–`surah114`, `surah-icon`)
- https://qul.tarteel.ai/mushaf_layouts/19?page_number=600
- https://github.com/TarteelAI/quranic-universal-library/blob/main/app/views/shared/_chapter_name.html.erb

The reference Mushaf 19 preview renders the common `header` ligature and overlays
the V4 name and `surah-icon`. No 1441 PNG or third-party traced ornament is used.
The Basmala in our page reader retains its original QCF page-1 glyphs; no border
has been invented for it. Original verse-end glyphs and COLRv1 palettes are unchanged.

Resource version: `qul-qcf-v4-decorations-1`, retrieved 2026-10-08.
Do not redistribute these files as a standalone font collection.
