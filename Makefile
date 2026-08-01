SHELL := /usr/bin/env bash

ARCHIVE ?= zavod70-20260801T082255Z-1-001.zip

.PHONY: check inspect prepare setup-vipe setup-splatfacto vipe-smoke vipe-full colmap-smoke colmap-full splat-smoke splat-full

check:
	./scripts/check_environment.sh gpu

inspect:
	python3 ./scripts/prepare_dataset.py "$(ARCHIVE)" --inspect-only

prepare:
	python3 ./scripts/prepare_dataset.py "$(ARCHIVE)"

setup-vipe:
	./scripts/setup_vipe.sh

setup-splatfacto:
	./scripts/setup_splatfacto.sh

vipe-smoke:
	./scripts/run_vipe.sh smoke

vipe-full:
	./scripts/run_vipe.sh full

colmap-smoke:
	./scripts/convert_to_colmap.sh smoke

colmap-full:
	./scripts/convert_to_colmap.sh full

splat-smoke:
	./scripts/train_splat.sh smoke

splat-full:
	./scripts/train_splat.sh full
