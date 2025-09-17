SHELL := /usr/bin/bash
SCRIPTS := $(shell find bash-scripts -type f -name "*.sh")

.PHONY: format lint check run
format:
	shfmt -w $(SCRIPTS)
lint:
	shellcheck -x $(SCRIPTS)
check: format lint
run:
	bash bash-scripts/disk_cleanup.sh

