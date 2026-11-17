# Editable project assets

- `speech/es` and `speech/en`: prepared signed PCM banks compressed with gzip,
  unit metadata and message scores. No speech model is required for a build.
- `english/translation.json`: English text by stable original entry ID.
  Verb and noun aliases are in `tools/localize.py`.
- `branding`: DiHalt logo, PCM instruments and OPL4 event stream. The builder
  converts the logo and packs BRAND.DAT.
- `originals.json` and `graphics.json`: identities of the separately supplied
  original inputs; the inputs themselves are not included.

See `docs/DESIGN.md` for sample and score layouts and `VOICE-NOTICE.txt` for
attribution. Original game text and artwork retain their original rights.

- `msx2`: enhanced indexed room pictures, recoloured opening, presentation
  image, exact VDP palettes and room mapping. The font is extracted at build
  time from the separately supplied original tape.
