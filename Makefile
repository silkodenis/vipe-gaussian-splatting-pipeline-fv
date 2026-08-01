SHELL := /usr/bin/env bash

-include .env

DATASET_ARCHIVE ?= zavod70-20260801T082255Z-1-001.zip
DATASET_NAME ?= zavod70
PREPARED_WIDTH ?= 1280
CAPTURE_FPS ?= 1
SMOKE_FRAMES ?= 20

.PHONY: bootstrap check inspect prepare setup-vipe setup-splatfacto vipe-smoke vipe-full colmap-smoke colmap-full splat-smoke splat-full

bootstrap:
	./scripts/bootstrap_ubuntu.sh

check:
	./scripts/check_environment.sh gpu

inspect:
	python3 ./scripts/prepare_dataset.py "$(DATASET_ARCHIVE)" \
		--dataset-name "$(DATASET_NAME)" \
		--width "$(PREPARED_WIDTH)" \
		--fps "$(CAPTURE_FPS)" \
		--smoke-frames "$(SMOKE_FRAMES)" \
		--inspect-only

prepare:
	python3 ./scripts/prepare_dataset.py "$(DATASET_ARCHIVE)" \
		--dataset-name "$(DATASET_NAME)" \
		--width "$(PREPARED_WIDTH)" \
		--fps "$(CAPTURE_FPS)" \
		--smoke-frames "$(SMOKE_FRAMES)"

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
