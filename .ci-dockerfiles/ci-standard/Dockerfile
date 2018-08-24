FROM ubuntu:16.04

ENV PONYC_VERSION 0.24.4
ENV PONY_STABLE_VERSION 0.1.4
ENV OTP_VERSION 1:20.2.2
ENV ELIXIR_VERSION 1.5.2-1

RUN apt-get update \
  && apt-get install -y \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     software-properties-common \
  && apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "E04F0923 B3B48BDA" \
  && add-apt-repository "deb https://dl.bintray.com/pony-language/ponylang-debian  $(lsb_release -cs) main" \
  && apt-get update \
  && apt-get install -y \
    build-essential \
    git \
    liblz4-dev \
    libpcre2-dev \
    libsnappy-dev \
    libssl-dev \
    make \
    ponyc=${PONYC_VERSION} \
    pony-stable=${PONY_STABLE_VERSION} \
    python \
    python-dev \
    python-pip \
    python3 \
    python3-dev \
    python3-pip \
    wget

# install MonHub dependencies
WORKDIR /tmp

RUN echo "deb http://binaries.erlang-solutions.com/debian xenial contrib" >> /etc/apt/sources.list.d/erlang-solutions.list \
  && wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc \
  && apt-key add erlang_solutions.asc \
  && apt-get update -q \
  && apt-get install -y \
  esl-erlang=$OTP_VERSION elixir=$ELIXIR_VERSION \
  npm

# Set locale, elixir needs this
RUN apt-get clean && apt-get update && apt-get install -y locales apt-utils
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

# python2 testing dependencies
RUN python2 -m pip install --upgrade pip enum34 \
  && python2 -m pip install pytest==3.2.2

# python3 testing dependencies
RUN python3 -m pip install --upgrade pip enum34 \
  && python3 -m pip install pytest==3.7.1

# install go
RUN wget https://dl.google.com/go/go1.9.2.linux-amd64.tar.gz \
  && tar -C /usr/local -xzf go1.9.2.linux-amd64.tar.gz

ENV PATH $PATH:/usr/local/go/bin

WORKDIR /
