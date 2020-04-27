FROM ubuntu:latest

ENV DEBIAN_FRONTEND noninteractive

ADD install_clir.sh /tmp/install_clir.sh

RUN set -e \
      && ln -sf /bin/bash /bin/sh

RUN set -e \
      && apt-get -y update \
      && apt-get -y dist-upgrade \
      && apt-get -y install --no-install-recommends --no-install-suggests \
        apt-transport-https apt-utils ca-certificates curl g++ gcc gfortran \
        git make libblas-dev libcurl4-gnutls-dev libgit2-dev liblapack-dev \
        libssh-dev libssl-dev libxml2-dev r-base \
      && apt-get -y autoremove \
      && apt-get clean \
      && rm -rf /var/lib/apt/lists/*

RUN set -e \
      && bash /tmp/install_clir.sh --root \
      && rm -f /tmp/install_clir.sh

ENTRYPOINT ["/usr/local/bin/clir"]
