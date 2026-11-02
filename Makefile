SHELL := /bin/bash

.DEFAULT_GOAL := help

CHEZMOI ?= chezmoi
SOURCE_DIR := $(CURDIR)
BASH ?= bash
FISH ?= fish
CHEZMOI_ARGS ?=

.PHONY: help install apply chezmoi-apply test test-fish test-sh test-install test-nvim test-herdr test-cloudtop

help:
	@echo 'Targets:'
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

install:
	./install.sh

apply:
	$(CHEZMOI) -S "$(SOURCE_DIR)" apply $(CHEZMOI_ARGS)

chezmoi-apply: apply

test: test-fish test-sh test-install test-nvim test-herdr test-cloudtop

test-fish:
	$(FISH) tests/config.fish.test.fish

test-sh:
	$(BASH) tests/config.sh.test.sh
	python3 tests/shell-startup.test.py

test-install:
	$(BASH) tests/install.test.sh

test-nvim:
	$(BASH) tests/nvim.test.sh

test-herdr:
	python3 -m unittest discover -s tests -p 'test_herdr*.py'

test-cloudtop:
	python3 -m unittest discover -s tests -p test_cloudtop.py
