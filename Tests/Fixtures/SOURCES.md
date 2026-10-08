# QCF V4 rendering test references

`qcf-decor-reference.json` contains only the words of four pages from QUL's
public Mushaf 19 proofreading views, retrieved 2026-10-08:

- https://qul.tarteel.ai/mushaf_layouts/19?page_number=1
- https://qul.tarteel.ai/mushaf_layouts/19?page_number=2
- https://qul.tarteel.ai/mushaf_layouts/19?page_number=187
- https://qul.tarteel.ai/mushaf_layouts/19?page_number=600

Each word retains its glyph, line, verse key, position and end-marker status.
Expected header lines: page 1 = 1; page 2 = 1; page 187 = 1;
page 600 = 4 and 11. Basmala lines: page 2 = 2; page 600 = 5 and 12.
Fatiha's Basmala is verse 1, not a second added decoration. Tawbah has none.

These references are included in the **unit test bundle only**. They are not
shipped as Quran data in the application. Production page data remains supplied
by the existing Quran Foundation repository and Content Sync pipeline.
