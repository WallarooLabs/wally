FROM ubuntu:16.04

ENV PONYC_VERSION 0.21.0-4301.acd811b
ENV PONY_STABLE_VERSION 0.1.1-70.6c4de6b

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "D401AB61 DBE1D0A2" \
  && echo "deb http://dl.bintray.com/pony-language/ponyc-debian pony-language main" >> /etc/apt/sources.list \
  && echo "deb http://dl.bintray.com/pony-language/pony-stable-debian /" >> /etc/apt/sources.list \
  && apt-get update \
  && apt-get install -y \
    build-essential \
    cpuset \
    git \
    liblz4-dev \
    libsnappy-dev \
    libssl-dev \
    make \
    ponyc=${PONYC_VERSION} \
    pony-stable=${PONY_STABLE_VERSION} \
    python \
    python-dev \
    python-pip \
    wget

# python testing dependencies
RUN python2 -m pip install --upgrade pip enum34 \
  && python2 -m pip install pytest==3.2.2
