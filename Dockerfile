FROM ubuntu:latest

ENV DEBIAN_FRONTEND noninteractive

ADD https://raw.githubusercontent.com/dceoy/clir/master/install.sh /tmp/install.sh

RUN set -e \
      && ln -sf /bin/bash /bin/sh

RUN set -e \
      && apt-get -y update \
      && apt-get -y dist-upgrade \
      && apt-get -y install --no-install-recommends --no-install-suggests \
        g++ gcc gfortran git make libblas-dev libcurl4-gnutls-dev \
        liblapack-dev libssl-dev libxml2-dev r-base \
      && apt-get -y autoremove \
      && apt-get clean \
      && rm -rf /var/lib/apt/lists/*

RUN set -e \
      && bash /tmp/install.sh --root \
      && rm -f /tmp/install.sh

ENTRYPOINT ["/usr/local/bin/clir"]
