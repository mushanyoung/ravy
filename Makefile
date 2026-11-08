SHELL := /bin/bash

.DEFAULT_GOAL := help

CHEZMOI ?= chezmoi
SOURCE_DIR := $(CURDIR)
BASH ?= bash
FISH ?= fish
PYTHON ?= $(CURDIR)/.venv/bin/python
CHEZMOI_ARGS ?=
CHECK_MISE := env MISE_CONFIG_DIR="$(CURDIR)/scripts/mise" mise
QUALITY := $(CHECK_MISE) exec --locked -- uv run --locked python scripts/quality.py

.PHONY: setup check format format-check lint typecheck unit e2e build

setup:
	$(CHECK_MISE) install --locked
	$(CHECK_MISE) exec --locked -- uv sync --frozen

check format format-check lint typecheck unit e2e build:
	$(QUALITY) $@

.PHONY: help install apply chezmoi-apply test test-fish test-sh test-install test-nvim test-herdr test-cloudtop

help:
	@echo 'Targets:'
	@echo '  make setup          Install the locked development toolchain'
	@echo '  make check          Format, lint, types, unit, E2E, production render'
	@echo '  make format         Apply the shared formatters'
	@echo '  make format-check lint typecheck unit e2e build  Run one gate'
	@echo '  make install        Run install.sh bootstrap'
	@echo '  make apply          Apply this chezmoi source to $$HOME'
	@echo '  make chezmoi-apply  Alias for apply'
	@echo '  make test           Run all shell config tests'
	@echo '  make test-fish      Run fish config test'
	@echo '  make test-sh        Run bash/zsh config test'
	@echo '  make test-install   Run installer regression test'
	@echo '  make test-nvim      Run Neovim config rendering test'
	@echo '  make test-herdr    Run Herdr config and compatibility tests'
	@echo '  make test-cloudtop  Run native Herdr entrypoint tests'
	@echo '  make lint-herdr     Alias for the locked lint gate'
	@echo '  make test-e2e-server     Real Linux server / PTY / SSH tests'
	@echo '  make test-e2e-developer  Real macOS/Linux SSH development tests'
	@echo '  make diagnose-herdr-agent-rotation  Strict opt-in known-limit diagnostic'

install:
	./install.sh

apply:
	$(CHEZMOI) -S "$(SOURCE_DIR)" apply $(CHEZMOI_ARGS)

chezmoi-apply: apply

.PHONY: lint-herdr test-e2e-developer test-e2e-server diagnose-herdr-agent-rotation

lint-herdr:
	$(QUALITY) lint

test-e2e-developer:
	$(PYTHON) tests/e2e_herdr.py --series developer

test-e2e-server:
	$(PYTHON) tests/e2e_herdr.py --series server

diagnose-herdr-agent-rotation:
	$(QUALITY) diagnostic

test: test-fish test-sh test-install test-nvim test-python test-dc

.PHONY: test-python
test-python:
	$(PYTHON) -m unittest discover -s tests -p 'test_*.py'

.PHONY: test-quality test-dc
test-quality:
	$(PYTHON) -m unittest discover -s tests -p 'test_quality.py'

test-dc:
	$(BASH) tests/dc.test.sh

test-fish:
	$(FISH) tests/config.fish.test.fish

test-sh:
	$(BASH) tests/config.sh.test.sh
	$(PYTHON) tests/shell-startup.test.py

test-install:
	$(BASH) tests/install.test.sh

test-nvim:
	$(BASH) tests/nvim.test.sh

test-herdr:
	$(PYTHON) -m unittest discover -s tests -p 'test_herdr*.py'
	$(PYTHON) -m unittest discover -s tests -p 'test_e2e_contract.py'

test-cloudtop:
	$(PYTHON) -m unittest discover -s tests -p test_cloudtop.py
