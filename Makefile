SHELL := /bin/bash

.DEFAULT_GOAL := help

CHEZMOI ?= chezmoi
SOURCE_DIR := $(CURDIR)
BASH ?= bash
FISH ?= fish
CHEZMOI_ARGS ?=

.PHONY: help install apply chezmoi-apply test test-fish test-sh

help:
	@echo 'Targets:'
	@echo '  make install        Run install.sh bootstrap'
	@echo '  make apply          Apply this chezmoi source to $$HOME'
	@echo '  make chezmoi-apply  Alias for apply'
	@echo '  make test           Run all shell config tests'
	@echo '  make test-fish      Run fish config test'
	@echo '  make test-sh        Run bash/zsh config test'

install:
	./install.sh

apply:
	$(CHEZMOI) -S "$(SOURCE_DIR)" apply $(CHEZMOI_ARGS)

chezmoi-apply: apply

test: test-fish test-sh

test-fish:
	$(FISH) tests/config.fish.test.fish

test-sh:
	$(BASH) tests/config.sh.test.sh
