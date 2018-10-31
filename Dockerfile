FROM ubuntu:xenial-20171006

# Set locale, required for Metrics UI
RUN apt-get update --fix-missing && apt-get install -y locales
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

ENV WALLAROO_VERSION 0.5.4

RUN apt-get install -y \
    curl \
    man \
    netcat-openbsd \
    curl \
    wget \
    less \
    dnsutils \
    net-tools \
    vim \
    sysstat \
    htop \
    numactl \
    python-dev \
    python-pip \
    python3-dev \
    python3-pip && \
    pip3 install virtualenv virtualenvwrapper && \
    pip3 install --upgrade pip && \
    pip2 install virtualenv virtualenvwrapper && \
    pip2 install --upgrade pip && \
    cd /tmp && \
    curl https://raw.githubusercontent.com/WallarooLabs/wallaroo/${WALLAROO_VERSION}/misc/wallaroo-up.sh -o wallaroo-up.sh -J -L && \
    chmod +x wallaroo-up.sh && \
    export WALLAROO_UP_SOURCE=docker && \
    export CUSTOM_WALLAROO_BUILD_ARGS="target_cpu=x86-64" && \
    echo y | ./wallaroo-up.sh -t all && \
    ln -s ~/wallaroo-tutorial/wallaroo-${WALLAROO_VERSION} /wallaroo-src && \
    cd /wallaroo-src && \
    sed -i "s@^export RELEASE_MUTABLE_DIR=.*@export RELEASE_MUTABLE_DIR=\"/tmp/metrics_ui\"@" bin/activate && \
    mkdir /wallaroo-bin && \
    cp docker/env-setup /wallaroo-bin && \
    make clean && \
    mkdir /src && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get -y autoremove --purge && \
    apt-get -y clean

VOLUME /src/wallaroo

ENV PATH /wallaroo-bin:$PATH

WORKDIR /src

ENTRYPOINT ["env-setup"]
