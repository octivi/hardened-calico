# SPDX-FileCopyrightText: 2026 IMAGIN sp. z o.o.
# SPDX-FileContributor: Marcin Engelmann <mengelmann@octivi.com>
# SPDX-License-Identifier: Apache-2.0
#
# Part of Octivi's hardened-calico, a derivative of Rancher's hardened-calico
# image: https://github.com/octivi/hardened-calico
#
# Created by Octivi's DevOps team: https://octivi.com/devops

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

include versions.env

IMAGE ?= ghcr.io/octivi/hardened-calico
BUILD_DIR := .build
K3S_ROOT_ARCHIVE := $(BUILD_DIR)/k3s-root-amd64.tar
BASE_IMAGE := $(CALICO_IMAGE):$(CALICO_TAG)@$(CALICO_DIGEST)
VCS_REF := $(shell git rev-parse --verify HEAD 2>/dev/null || printf 'unknown')

.PHONY: validate download verify build test push clean

validate:
	[[ "$(K3S_ROOT_SHA256)" =~ ^[0-9a-f]{64}$$ ]] || { echo "Set K3S_ROOT_SHA256 in versions.env" >&2; exit 1; }
	[[ "$(CALICO_DIGEST)" =~ ^sha256:[0-9a-f]{64}$$ ]] || { echo "Set CALICO_DIGEST in versions.env" >&2; exit 1; }

download: validate
	mkdir -p "$(BUILD_DIR)"
	gh release download "$(K3S_ROOT_RELEASE)" \
		--repo "$(K3S_ROOT_REPOSITORY)" \
		--pattern k3s-root-amd64.tar \
		--dir "$(BUILD_DIR)" \
		--clobber

verify: download
	printf '%s  %s\n' \
		'$(K3S_ROOT_SHA256)' \
		'$(K3S_ROOT_ARCHIVE)' | sha256sum --check -

build: verify
	docker build \
		--build-arg "BASE_IMAGE=$(BASE_IMAGE)" \
		--build-arg "NFTABLES_VERSION=$(NFTABLES_VERSION)" \
		--build-arg "VCS_REF=$(VCS_REF)" \
		--tag "$(IMAGE):$(IMAGE_TAG)" \
		.

test: build
	docker run --rm \
		--entrypoint /usr/sbin/nft \
		"$(IMAGE):$(IMAGE_TAG)" \
		--version

push: test
	docker push "$(IMAGE):$(IMAGE_TAG)"

clean:
	rm -f "$(K3S_ROOT_ARCHIVE)"
	rmdir "$(BUILD_DIR)" 2>/dev/null || true
