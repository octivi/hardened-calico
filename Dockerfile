# syntax=docker/dockerfile:1.7

# SPDX-FileCopyrightText: 2026 IMAGIN sp. z o.o.
# SPDX-FileContributor: Marcin Engelmann <mengelmann@octivi.com>
# SPDX-License-Identifier: Apache-2.0
#
# Part of Octivi's hardened-calico, a derivative of Rancher's hardened-calico
# image: https://github.com/octivi/hardened-calico
#
# Created by Octivi's DevOps team: https://octivi.com/devops

ARG BASE_IMAGE

FROM scratch AS k3s-root

ADD .build/k3s-root-amd64.tar /

FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG NFTABLES_VERSION
ARG VCS_REF=unknown

COPY --from=k3s-root --chmod=0755 /bin/aux/nft /usr/sbin/nft

RUN set -eu; \
    actual_version="$(/usr/sbin/nft --version)"; \
    case "${actual_version}" in \
        "nftables v${NFTABLES_VERSION}"*) ;; \
        *) echo "Unexpected nftables version: ${actual_version}" >&2; exit 1 ;; \
    esac

LABEL org.opencontainers.image.title="hardened-calico"
LABEL org.opencontainers.image.vendor="IMAGIN sp. z o.o."
LABEL org.opencontainers.image.authors="Marcin Engelmann <mengelmann@octivi.com>"
LABEL org.opencontainers.image.source="https://github.com/octivi/hardened-calico"
LABEL org.opencontainers.image.description="Rancher hardened-calico with an updated nft binary"
LABEL org.opencontainers.image.base.name="${BASE_IMAGE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
