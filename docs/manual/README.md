# Player manuals — version 2.0

`manual-es.pdf` and `manual-en.pdf` describe the same public MSX-DOS package:
both languages, the MSX1/MSX2 selector, installation, controls, linked parts,
opening-key waits and credits. All referenced artwork is included in `assets/`.

The public repository keeps these sources under `docs/manual/`:
`manual.tex`, `content-es.tex`, `content-en.tex`, language entry points and
`build.sh`. Run `make manual TECTONIC=tectonic` to rebuild the PDFs.

The player manuals describe the game files in `SD/` and use an existing
MSX-DOS/Nextor installation. The technical references are separate:
`TECNICA-es.pdf/html` and `TECNICA-en.pdf/html`.

Illustration and historical credits are listed in `SOURCES.md`.
