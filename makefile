# Universal Makefile for Bitcoin Austria Presentations
#
# Each presentation lives in its own subdirectory:
#   ./[name]/[name].tex  (e.g., ./2026-meine-praesentation/2026-meine-praesentation.tex)
#
# Usage: make [target] PRESENTATION=keyword
# The keyword is fuzzy-matched using .claude/find-presentation.sh

.PHONY: all build build-verbose clean clean-all view help screenshot-samples screenshot-page watch watch-quiet format logos

# Default presentation (if not specified)
ifndef PRESENTATION
    PRESENTATION := $(shell ./.claude/find-presentation.sh 2>/dev/null | head -1)
endif

# Find presentation directory using fuzzy matching
PRES_DIR := $(shell ./.claude/find-presentation.sh $(PRESENTATION) 2>/dev/null)
PRES_NAME := $(notdir $(PRES_DIR))
TEX_FILE := $(PRES_DIR)/$(PRES_NAME).tex
PDF_FILE := $(PRES_DIR)/$(PRES_NAME).pdf

# Verify presentation was found
ifeq ($(PRES_DIR),)
    $(error No presentation found matching '$(PRESENTATION)'. Run 'make help' to see available presentations)
endif

# Default target
all: build

# Convert SVG logos to cropped PDFs (only when SVG is newer)
logos/logo-bitcoin-austria.pdf: logos/Bitcoin_Austria_Logo_Horizontal_Light.svg
	@echo "Converting Bitcoin Austria logo SVG to PDF..."
	@inkscape --export-type=pdf --export-filename=logos/logo-bitcoin-austria-temp.pdf logos/Bitcoin_Austria_Logo_Horizontal_Light.svg
	@echo "Cropping PDF to content..."
	@pdfcrop logos/logo-bitcoin-austria-temp.pdf logos/logo-bitcoin-austria.pdf
	@rm -f logos/logo-bitcoin-austria-temp.pdf
	@echo "Logo processed: logos/logo-bitcoin-austria.pdf"

logos: logos/logo-bitcoin-austria.pdf

# Handle presentation-specific generated files (e.g., generated-count.tex)
$(PRES_DIR)/generated-count.tex: $(TEX_FILE)
	@if [ -f "$(PRES_DIR)/count-items.sh" ]; then \
		echo "Counting content in $(PRES_DIR)..."; \
		cd $(PRES_DIR) && ./count-items.sh; \
	else \
		touch $(PRES_DIR)/generated-count.tex; \
	fi

# Build the presentation PDF
build: logos/logo-bitcoin-austria.pdf $(PRES_DIR)/generated-count.tex
	@echo "Building $(PRES_NAME) presentation..."
	@cd $(PRES_DIR) && latexmk -pdfxe -f -interaction=nonstopmode -silent $(PRES_NAME).tex || true
	@test -f $(PDF_FILE) || (echo "Build failed. PDF not created. Run 'make build-verbose PRESENTATION=$(PRESENTATION)' for details." && exit 1)
	@echo "Build complete: $(PDF_FILE)"

# Build with full output for debugging
build-verbose: logos/logo-bitcoin-austria.pdf $(PRES_DIR)/generated-count.tex
	@echo "Building $(PRES_NAME) presentation (verbose)..."
	@cd $(PRES_DIR) && latexmk -pdfxe -f -interaction=nonstopmode $(PRES_NAME).tex
	@echo "Build complete: $(PDF_FILE)"

# Clean auxiliary files but keep the PDF
clean:
	@echo "Cleaning auxiliary files in $(PRES_DIR)..."
	@cd $(PRES_DIR) && latexmk -c $(PRES_NAME).tex
	@cd $(PRES_DIR) && rm -f $(PRES_NAME).nav $(PRES_NAME).snm $(PRES_NAME).vrb
	@cd $(PRES_DIR) && rm -f *-count.tex generated-count.tex *.aux *.fdb_latexmk
	@cd $(PRES_DIR) && rm -rf screenshots/ .latexindent-tmp/
	@echo "Clean complete for $(PRES_NAME)"

# Clean everything including the PDF
clean-all:
	@echo "Cleaning all generated files in $(PRES_DIR)..."
	@cd $(PRES_DIR) && latexmk -C $(PRES_NAME).tex
	@echo "Deep clean complete for $(PRES_NAME)"

# View the PDF
view: build
	@echo "Opening $(PDF_FILE)..."
	@if command -v xdg-open > /dev/null 2>&1; then \
		xdg-open $(PDF_FILE); \
	elif command -v open > /dev/null 2>&1; then \
		open $(PDF_FILE); \
	else \
		echo "No PDF viewer found. Please open $(PDF_FILE) manually."; \
	fi

# Format LaTeX source file
format:
	@echo "Formatting $(TEX_FILE)..."
	@cd $(PRES_DIR) && mkdir -p .latexindent-tmp
	@cd $(PRES_DIR) && latexindent -w -c .latexindent-tmp $(PRES_NAME).tex > /dev/null 2>&1 || (echo "Formatting failed. Check LaTeX syntax." && exit 1)
	@echo "LaTeX source formatted for $(PRES_NAME)"

# Take sample screenshots for style verification
screenshot-samples: build
	@echo "Taking sample screenshots for $(PRES_NAME)..."
	@cd $(PRES_DIR) && mkdir -p screenshots
	@cd $(PRES_DIR) && TOTAL_PAGES=$$(pdftk "$(PRES_NAME).pdf" dump_data | grep NumberOfPages | cut -d' ' -f2 2>/dev/null || echo "10"); \
	echo "Total pages: $$TOTAL_PAGES"; \
	../screenshot-page.sh $(PRES_NAME).pdf 1 title; \
	../screenshot-page.sh $(PRES_NAME).pdf 2 slide_2; \
	../screenshot-page.sh $(PRES_NAME).pdf $$TOTAL_PAGES last
	@echo "Screenshots saved in $(PRES_DIR)/screenshots/"

# Screenshot a specific page
screenshot-page: build
	@if [ -z "$(PAGE)" ]; then \
		echo "Error: Please specify PAGE number. Example: make screenshot-page PAGE=4 NAME=example PRESENTATION=$(PRESENTATION)"; \
	else \
		cd $(PRES_DIR) && ../screenshot-page.sh $(PRES_NAME).pdf $(PAGE) $(if $(NAME),$(NAME),page_$(PAGE)); \
	fi

# Watch for changes and rebuild (verbose)
watch: logos/logo-bitcoin-austria.pdf $(PRES_DIR)/generated-count.tex
	@echo "Starting continuous compilation for $(PRES_NAME)..."
	@echo "Press Ctrl+C to stop watching"
	@cd $(PRES_DIR) && latexmk -pdfxe -f -interaction=nonstopmode -pvc $(PRES_NAME).tex

# Watch for changes and rebuild (quiet)
watch-quiet: logos/logo-bitcoin-austria.pdf $(PRES_DIR)/generated-count.tex
	@echo "Starting quiet continuous compilation for $(PRES_NAME)..."
	@echo "Press Ctrl+C to stop watching"
	@cd $(PRES_DIR) && latexmk -pdfxe -f -interaction=batchmode -silent -pvc $(PRES_NAME).tex

# Show help
help:
	@echo "Universal Bitcoin Austria Presentation Makefile"
	@echo ""
	@echo "Usage: make [target] PRESENTATION=keyword"
	@echo ""
	@echo "Available presentations:"
	@./.claude/find-presentation.sh 2>&1 || true
	@echo ""
	@echo "Available targets:"
	@echo "  make [PRESENTATION=key]              - Build presentation"
	@echo "  make build [PRESENTATION=key]        - Build PDF (quiet)"
	@echo "  make build-verbose [PRESENTATION=key]- Build with full LaTeX output"
	@echo "  make format [PRESENTATION=key]       - Format LaTeX source"
	@echo "  make clean [PRESENTATION=key]        - Clean auxiliary files, keep PDF"
	@echo "  make clean-all [PRESENTATION=key]    - Clean all files including PDF"
	@echo "  make view [PRESENTATION=key]         - Build and view PDF"
	@echo "  make watch [PRESENTATION=key]        - Continuous compilation (verbose)"
	@echo "  make watch-quiet [PRESENTATION=key]  - Continuous compilation (quiet)"
	@echo "  make screenshot-samples [PRESENTATION=key] - Sample screenshots"
	@echo "  make screenshot-page PAGE=X NAME=desc [PRESENTATION=key]"
	@echo "  make logos                           - Regenerate logo PDFs from SVG"
	@echo "  make help                            - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make PRESENTATION=2026-meine"
	@echo "  make build-verbose PRESENTATION=meine"
	@echo "  make screenshot-page PAGE=3 NAME=intro PRESENTATION=meine"
	@echo ""
	@echo "Current target: $(PRES_NAME) ($(PRES_DIR))"
