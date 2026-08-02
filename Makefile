SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

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

.PHONY: help bootstrap check inspect prepare setup setup-vipe diagnose diagnose-vipe setup-splatfacto diagnose-splatfacto pipeline-smoke pipeline-full vipe-smoke vipe-full colmap-smoke colmap-full splat-smoke splat-full resume-splat-smoke resume-splat-full validate-splat-smoke validate-splat-full view-splat-smoke view-splat-full render-splat-smoke render-splat-full

help: ## Show all available commands
	@awk 'BEGIN { FS = ":.*## "; printf "Usage: make <command>\n" } /^##@ / { printf "\n%s\n", substr($$0, 5) } /^[a-zA-Z0-9_-]+:.*## / { printf "  %-24s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

##@ Environment

bootstrap: ## Install system packages and project-local Conda
	./scripts/bootstrap_ubuntu.sh

check: ## Check host, GPU, tools, disk, and Conda prerequisites
	./scripts/check_environment.sh gpu

diagnose: ## Diagnose both ViPE and Splatfacto environments
	$(MAKE) diagnose-vipe
	$(MAKE) diagnose-splatfacto

setup: ## Install both pinned ViPE and Splatfacto environments
	$(MAKE) setup-vipe
	$(MAKE) setup-splatfacto

setup-vipe: ## Install the pinned ViPE environment
	./scripts/setup_vipe.sh

diagnose-vipe: ## Validate the ViPE environment and CUDA runtime
	./scripts/diagnose_vipe.sh

setup-splatfacto: ## Install the pinned Nerfstudio/Splatfacto environment
	./scripts/setup_splatfacto.sh

diagnose-splatfacto: ## Validate the Nerfstudio/Splatfacto environment
	./scripts/diagnose_splatfacto.sh

##@ Dataset

inspect: ## Validate and summarize input images without preparing videos
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

prepare: ## Validate images and prepare full and smoke MP4 inputs
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

##@ Complete pipelines

pipeline-smoke: ## Run ViPE, COLMAP export, and Splatfacto smoke stages
	$(MAKE) vipe-smoke
	$(MAKE) colmap-smoke
	$(MAKE) splat-smoke

pipeline-full: ## Run ViPE, COLMAP export, and Splatfacto full stages
	$(MAKE) vipe-full
	$(MAKE) colmap-full
	$(MAKE) splat-full

##@ ViPE and COLMAP

vipe-smoke: ## Run ViPE on the smoke video
	./scripts/run_vipe.sh smoke

vipe-full: ## Run ViPE on the complete video
	./scripts/run_vipe.sh full

colmap-smoke: ## Export the smoke ViPE result to COLMAP format
	./scripts/convert_to_colmap.sh smoke

colmap-full: ## Export the complete ViPE result to COLMAP format
	./scripts/convert_to_colmap.sh full

##@ Splatfacto

splat-smoke: ## Train the smoke Splatfacto model
	./scripts/train_splat.sh smoke

splat-full: ## Train the complete Splatfacto model
	./scripts/train_splat.sh full

resume-splat-smoke: ## Resume smoke training from its latest checkpoint
	./scripts/train_splat.sh smoke resume

resume-splat-full: ## Resume full training from its latest checkpoint
	./scripts/train_splat.sh full resume

validate-splat-smoke: ## Validate the completed smoke model and checkpoint
	./scripts/validate_splat.sh smoke

validate-splat-full: ## Validate the completed full model and checkpoint
	./scripts/validate_splat.sh full

##@ Viewer and rendering

view-splat-smoke: ## Open the smoke model in the Nerfstudio Viewer
	./scripts/view_splat.sh smoke

view-splat-full: ## Open the full model with ordered camera keyframes
	./scripts/view_splat.sh full

render-splat-smoke: ## Render the newest smoke Viewer camera path
	./scripts/render_splat.sh smoke

render-splat-full: ## Render the newest full Viewer camera path
	./scripts/render_splat.sh full
