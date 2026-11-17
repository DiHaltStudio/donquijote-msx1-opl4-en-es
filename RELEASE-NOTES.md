# Don Quijote / Don Quixote — MSX-DOS + OPL4 v1.01

This update adds a memory requirements report before the game starts, in both Spanish and English.

- Detects compatible mapper RAM and OPL4 sample RAM, including mirrored memory banks.
- Shows RAM reserved for the game and the required minimums.
- Explains missing or insufficient memory and returns to DOS.
- Uses a bounded OPL4 status wait for absent or unresponsive hardware.
- Separates file-loading errors from memory errors and names the requested data file.
- Updates both illustrated player manuals.

**Installation:** download `donquijote-msx1-opl4-en-es-1.01.zip` and copy all files from `SD/` into one folder (the drive root under DOS1). Run `QUIJOTE` for Spanish or `QUIXOTE` for English. Press RETURN after the memory report, then start part one or enter the classic part-two password.

**Updating from v1.0:** replace QUIJOTE.COM and QUIXOTE.COM. Existing voice and picture data can be kept; the complete bilingual package is also included.

Requires MSX1 or later, 512 KiB RAM in one compatible mapper, and OPL4 with 2 MiB sample RAM. Supports MSX-DOS 1 and MSX-DOS 2/Nextor. The current loader expects a MegaFlashROM SCC+ SD-style mapper arrangement; the new report distinguishes RAM not located by this loader from insufficient capacity.

The automatic “Source code” archives contain build sources. Download the named bilingual ZIP to play.

Original game: Dinamic Software, 1987. Unofficial adaptation and homage by DiHalt Studio, 2026. Original game elements belong to their respective holders.
