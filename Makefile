.DEFAULT_GOAL := all
PYTHON ?= python3
SJASM ?= sjasm
TECTONIC ?= tectonic
OPENMSX ?= openmsx
VERSION ?= 1.01
ORIGINAL_DIR ?= third_party/original
GRAPHICS_DIR ?= third_party/graphics
RELEASE_DIR ?=
.PHONY: all help extract graphics import-graphics release manual clean check
all:
	SJASM="$(SJASM)" $(PYTHON) tools/build.py --originals "$(ORIGINAL_DIR)" --graphics "$(GRAPHICS_DIR)"
extract:
	$(PYTHON) tools/build.py --originals "$(ORIGINAL_DIR)" --extract-only
graphics: extract
	$(PYTHON) tools/render_graphics.py --openmsx "$(OPENMSX)"
	$(PYTHON) tools/import_graphics.py build/graphics
import-graphics:
	@test -n "$(RELEASE_DIR)" || { echo 'Use make import-graphics RELEASE_DIR=/path/to/downloaded/package'; exit 1; }
	$(PYTHON) tools/import_graphics.py "$(RELEASE_DIR)"
release: all
	$(PYTHON) tools/package.py --version "$(VERSION)"
manual:
	cd docs/manual && TECTONIC="$(TECTONIC)" ./build.sh
check:
	$(PYTHON) tools/check_sources.py
clean:
	rm -rf build docs/manual/build
help:
	@echo 'make                  Build both languages into build/SD (no emulator)'
	@echo 'make release          Build one bilingual folder and ZIP in release/'
	@echo 'make import-graphics RELEASE_DIR=...  Import drawings from a downloaded package'
	@echo 'make graphics         Render original drawings with openMSX (explicit optional step)'
	@echo 'make manual           Rebuild both PDF manuals using Tectonic'
	@echo 'make check            Check source inputs and public file hygiene'
	@echo 'make clean            Remove intermediate build files; keep releases and inputs'
