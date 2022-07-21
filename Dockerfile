FROM ubuntu:latest

ENV DEBIAN_FRONTEND noninteractive

ADD install_clir.sh /tmp/install_clir.sh

RUN set -e \
      && ln -sf bash /bin/sh

RUN set -e \
      && apt-get -y update \
      && apt-get -y dist-upgrade \
      && apt-get -y install --no-install-recommends --no-install-suggests \
        apt-transport-https apt-utils ca-certificates curl g++ gcc gfortran \
        git libblas-dev libcurl4-gnutls-dev libfontconfig1-dev \
        libfreetype6-dev libfribidi-dev libgit2-dev libharfbuzz-dev \
        libjpeg-dev liblapack-dev libpng-dev libssh-dev libssl-dev \
        libtiff5-dev libxml2-dev make r-base \
      && apt-get -y autoremove \
      && apt-get clean \
      && rm -rf /var/lib/apt/lists/*

RUN set -e \
      && bash /tmp/install_clir.sh --root \
      && rm -f /tmp/install_clir.sh

ENTRYPOINT ["/usr/local/bin/clir"]
