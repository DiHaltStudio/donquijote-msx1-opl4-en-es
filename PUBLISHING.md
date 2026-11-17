# Publishing

Repository: https://github.com/DiHaltStudio/donquijote-msx1-opl4-en-es

The source folder is prepared without Git history. Initialize and publish it
when ready:

```sh
git init -b main
git add .
git status --short
git commit -m "Initial bilingual MSX-DOS OPL4 edition"
git remote add origin https://github.com/DiHaltStudio/donquijote-msx1-opl4-en-es.git
git push -u origin main
```

The ignore rules keep original inputs, extracted game data, build intermediates
and release payloads out of the source repository. Review the staged file list
before committing. Do not force-add those ignored directories.

For the downloadable release:

- Tag: `v1.01`.
- Title: **Don Quijote / Don Quixote — MSX-DOS + OPL4 v1.01**.
- Description: use `RELEASE-NOTES.md`.
- Attach `release/donquijote-msx1-opl4-en-es-1.01.zip` and `release/SHA256SUMS`.
- Optionally attach the two PDFs from `docs/manual/` separately; they are also
  included in the ZIP.

The ZIP contains the playable bilingual package. GitHub's automatically created
source archives contain the build sources and require the separate original
inputs described in `docs/BUILDING.md`.
