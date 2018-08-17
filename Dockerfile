FROM ubuntu:xenial-20171006

# Set locale, required for Metrics UI
RUN apt-get update && apt-get install -y locales
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

ENV PONYC_VERSION 0.24.4
ENV PONY_STABLE_VERSION 0.1.4-121.d8a403e

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "D401AB61 DBE1D0A2" && \
    echo "deb http://dl.bintray.com/pony-language/ponyc-debian pony-language main" >> /etc/apt/sources.list && \
    echo "deb http://dl.bintray.com/pony-language/pony-stable-debian /" >> /etc/apt/sources.list && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    ponyc=${PONYC_VERSION} \
    pony-stable=${PONY_STABLE_VERSION} \
    build-essential \
    libsnappy-dev \
    liblz4-dev \
    libssl-dev \
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
    python-pip  \
    python3-dev \
    python3-pip && \
    pip2 install virtualenv virtualenvwrapper && \
    pip2 install --upgrade pip && \
    pip3 install virtualenv virtualenvwrapper && \
    pip3 install --upgrade pip && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get -y autoremove --purge && \
    apt-get -y clean

RUN mkdir /src

COPY book /wallaroo-src/book/
COPY book.json /wallaroo-src/
COPY CHANGELOG.md /wallaroo-src/
COPY CODE_OF_CONDUCT.md /wallaroo-src/
COPY CONTRIBUTING.md /wallaroo-src/
COPY cover.jpg /wallaroo-src/
COPY Dockerfile /wallaroo-src/
COPY examples /wallaroo-src/examples/
COPY giles /wallaroo-src/giles/
COPY intro.md /wallaroo-src/
COPY lib /wallaroo-src/lib/
COPY LICENSE.md /wallaroo-src/
COPY LIMITATIONS.md /wallaroo-src/
COPY machida /wallaroo-src/machida/
COPY machida3 /wallaroo-src/machida3/
COPY Makefile /wallaroo-src/
COPY monitoring_hub /wallaroo-src/monitoring_hub/
COPY orchestration /wallaroo-src/orchesration/
COPY README.md /wallaroo-src/
COPY ROADMAP.md /wallaroo-src/
COPY rules.mk /wallaroo-src/
COPY SUMMARY.md /wallaroo-src/
COPY SUPPORT.md /wallaroo-src/
COPY utils /wallaroo-src/utils/
COPY docker/env-setup /wallaroo-src/
COPY testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg \
    /wallaroo-src/testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg
COPY testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg \
    /wallaroo-src/testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg
COPY testing/data/market_spread/orders/350-symbols_orders-fixish.msg \
    /wallaroo-src/testing/data/market_spread/orders/350-symbols_orders-fixish.msg

WORKDIR /wallaroo-src

RUN mkdir /metrics_ui-src && \
    cp -r /wallaroo-src/monitoring_hub/apps/metrics_reporter_ui/_build/prod/rel/metrics_reporter_ui /metrics_ui-src

RUN make clean && \
    make target_cpu=x86-64 build-giles-all && \
    make target_cpu=x86-64 build-utils-all && \
    make target_cpu=x86-64 build-machida-all && \
    make target_cpu=x86-64 build-machida3-all && \
    mkdir /wallaroo-bin && \
    cp giles/sender/sender /wallaroo-bin/sender && \
    cp giles/receiver/receiver /wallaroo-bin/receiver && \
    cp machida/build/machida /wallaroo-bin/machida && \
    cp machida3/build/machida3 /wallaroo-bin/machida3 && \
    cp utils/cluster_shutdown/cluster_shutdown /wallaroo-bin/cluster_shutdown && \
    cp utils/data_receiver/data_receiver /wallaroo-bin/data_receiver && \
    cp env-setup /wallaroo-bin && \
    make clean-machida-all && \
    make target_cpu=x86-64 build-machida-all resilience=on && \
    cp machida/build/machida /wallaroo-bin/machida-resilience && \
    make clean-machida3-all && \
    make target_cpu=x86-64 build-machida3-all resilience=on && \
    cp machida3/build/machida3 /wallaroo-bin/machida3-resilience && \
    make clean

VOLUME /src/wallaroo

ENV PATH /wallaroo-bin:/metrics_ui-src/metrics_reporter_ui/bin:$PATH
ENV PYTHONPATH /src/wallaroo/machida:$PYTHONPATH

WORKDIR /src

ENTRYPOINT ["env-setup"]
