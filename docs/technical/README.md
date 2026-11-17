# Technical reference — version 2.0

The public DOS edition is documented in equivalent Spanish and English texts:

- `TECNICA-es.pdf` and `TECNICA-es.html`
- `TECNICA-en.pdf` and `TECNICA-en.html`

`TECNICA-es.src.md` and `TECNICA-en.src.md` are the editable texts. `data.json`
contains the distributed file sizes and prepared speech metadata used in their
tables. Each language has its own eight SVG diagrams under `figures/`.

The HTML files embed their diagrams and work without external image files.
The PDF files contain the same text, tables and illustrations as their HTML.

To rebuild using the public repository:

```sh
python3 -m venv .venv-docs
.venv-docs/bin/pip install -r requirements-docs.txt
make technical-docs DOCS_PYTHON=.venv-docs/bin/python
```

The renderer uses Markdown, Pillow and WeasyPrint, with DejaVu Sans fonts.
It reads only this documentation folder and does not need game inputs or an
emulator. Player instructions are separate in `docs/manual/`.
