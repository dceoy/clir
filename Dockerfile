# syntax=docker/dockerfile:1
ARG UBUNTU_VERSION=24.04
FROM public.ecr.aws/docker/library/ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND noninteractive

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN \
      rm -f /etc/apt/apt.conf.d/docker-clean \
      && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' \
        > /etc/apt/apt.conf.d/keep-cache

RUN \
      --mount=type=cache,target=/var/cache/apt,sharing=locked \
      --mount=type=cache,target=/var/lib/apt,sharing=locked \
      apt-get -y update \
      && apt-get -y upgrade \
      && apt-get -y install --no-install-recommends --no-install-suggests \
        apt-transport-https apt-utils ca-certificates curl g++ gcc gfortran \
        git libblas-dev libcurl4-gnutls-dev libfontconfig1-dev \
        libfreetype6-dev libfribidi-dev libgit2-dev libharfbuzz-dev \
        libjpeg-dev liblapack-dev libpng-dev libssh-dev libssl-dev \
        libtiff5-dev libxml2-dev make r-base

RUN \
      --mount=type=cache,target=/root/.cache \
      --mount=type=bind,source=.,target=/mnt/host \
      bash /mnt/host/install_clir.sh --root

HEALTHCHECK NONE

ENTRYPOINT ["/usr/local/bin/clir"]
