# Publishing version 2.0

Repository: https://github.com/DiHaltStudio/donquijote-msx1-opl4-en-es

Run `make release VERSION=2.0` with the original inputs described in
`docs/BUILDING.md`. The outputs under `release/` are ignored by Git.
Commit source and documentation changes, then push the main branch.

Create tag `v2.0` at that commit. Use `RELEASE-NOTES.md` as the description.
Attach the generated ZIP, SHA256SUMS and the six documents in its DOCS folder.
Original tapes, extracted game records, system ROMs and DOS kernels stay outside
the source repository. The downloadable ZIP contains the playable game package;
GitHub's automatic source archives contain its build sources.
