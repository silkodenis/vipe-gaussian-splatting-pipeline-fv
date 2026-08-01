SHELL := /usr/bin/env bash

-include .env

DATASET_INPUT_DIR ?= data/input/zavod70
DATASET_NAME ?= zavod70
PREPARED_WIDTH ?= 1280
CAPTURE_FPS ?= 1
SMOKE_FRAMES ?= 20
EXPECTED_CONTENT_SHA256 ?= e8f7dbe4ae97d225ef9b6daa1ff742e69459a8941f6bf6a546e0a1da2456ac9e
EXPECTED_FRAME_COUNT ?= 126
EXPECTED_FIRST_FRAME ?= 1
EXPECTED_LAST_FRAME ?= 126
EXPECTED_UNCOMPRESSED_BYTES ?= 1074302976

.PHONY: bootstrap check inspect prepare setup setup-vipe diagnose diagnose-vipe setup-splatfacto diagnose-splatfacto pipeline-smoke pipeline-full vipe-smoke vipe-full colmap-smoke colmap-full splat-smoke splat-full resume-splat-smoke resume-splat-full validate-splat-smoke validate-splat-full view-splat-smoke view-splat-full render-splat-smoke render-splat-full

bootstrap:
	./scripts/bootstrap_ubuntu.sh

check:
	./scripts/check_environment.sh gpu

inspect:
	python3 ./scripts/prepare_dataset.py "$(DATASET_INPUT_DIR)" \
		--dataset-name "$(DATASET_NAME)" \
		--width "$(PREPARED_WIDTH)" \
		--fps "$(CAPTURE_FPS)" \
		--smoke-frames "$(SMOKE_FRAMES)" \
		--expected-content-sha256 "$(EXPECTED_CONTENT_SHA256)" \
		--expected-frame-count "$(EXPECTED_FRAME_COUNT)" \
		--expected-first-frame "$(EXPECTED_FIRST_FRAME)" \
		--expected-last-frame "$(EXPECTED_LAST_FRAME)" \
		--expected-uncompressed-bytes "$(EXPECTED_UNCOMPRESSED_BYTES)" \
		--inspect-only

prepare:
	python3 ./scripts/prepare_dataset.py "$(DATASET_INPUT_DIR)" \
		--dataset-name "$(DATASET_NAME)" \
		--width "$(PREPARED_WIDTH)" \
		--fps "$(CAPTURE_FPS)" \
		--smoke-frames "$(SMOKE_FRAMES)" \
		--expected-content-sha256 "$(EXPECTED_CONTENT_SHA256)" \
		--expected-frame-count "$(EXPECTED_FRAME_COUNT)" \
		--expected-first-frame "$(EXPECTED_FIRST_FRAME)" \
		--expected-last-frame "$(EXPECTED_LAST_FRAME)" \
		--expected-uncompressed-bytes "$(EXPECTED_UNCOMPRESSED_BYTES)"

setup:
	$(MAKE) setup-vipe
	$(MAKE) setup-splatfacto

diagnose:
	$(MAKE) diagnose-vipe
	$(MAKE) diagnose-splatfacto

pipeline-smoke:
	$(MAKE) vipe-smoke
	$(MAKE) colmap-smoke
	$(MAKE) splat-smoke

pipeline-full:
	$(MAKE) vipe-full
	$(MAKE) colmap-full
	$(MAKE) splat-full

setup-vipe:
	./scripts/setup_vipe.sh

diagnose-vipe:
	./scripts/diagnose_vipe.sh

setup-splatfacto:
	./scripts/setup_splatfacto.sh

diagnose-splatfacto:
	./scripts/diagnose_splatfacto.sh

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

resume-splat-smoke:
	./scripts/train_splat.sh smoke resume

resume-splat-full:
	./scripts/train_splat.sh full resume

validate-splat-smoke:
	./scripts/validate_splat.sh smoke

validate-splat-full:
	./scripts/validate_splat.sh full

view-splat-smoke:
	./scripts/view_splat.sh smoke

view-splat-full:
	./scripts/view_splat.sh full

render-splat-smoke:
	./scripts/render_splat.sh smoke

render-splat-full:
	./scripts/render_splat.sh full
