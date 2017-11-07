FROM ubuntu:xenial-20171006

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "D401AB61 DBE1D0A2" && \
    echo "deb http://dl.bintray.com/pony-language/ponyc-debian pony-language main" >> /etc/apt/sources.list && \
    echo "deb http://dl.bintray.com/pony-language/pony-stable-debian /" >> /etc/apt/sources.list && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
# libraries and build tools
    git \
    ponyc \
    pony-stable \
    build-essential \
    libsnappy-dev \
    liblz4-dev \
    libssl-dev \
# useful tools/utilities
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
# python
    python-dev \
    python-pip && \
    pip install virtualenv virtualenvwrapper && \
    pip install --upgrade pip && \
# cleanup
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
COPY cpp_api /wallaroo-src/cpp_api/
COPY Dockerfile /wallaroo-src/
COPY examples /wallaroo-src/examples/
COPY giles /wallaroo-src/giles/
COPY intro.md /wallaroo-src/
COPY lib /wallaroo-src/lib/
COPY LICENSE.md /wallaroo-src/
COPY LIMITATIONS.md /wallaroo-src/
COPY machida /wallaroo-src/machida/
COPY Makefile /wallaroo-src/
COPY monitoring_hub /wallaroo-src/monitoring_hub/
COPY orchestration /wallaroo-src/orchesration/
COPY README.md /wallaroo-src/
COPY ROADMAP.md /wallaroo-src/
COPY rules.mk /wallaroo-src/
COPY SUMMARY.md /wallaroo-src/
COPY SUPPORT.md /wallaroo-src/
COPY utils /wallaroo-src/utils/
COPY scripts/docker-setup.sh /wallaroo-src/

RUN mkdir /metrics_ui-src && \
    cp -r /wallaroo-src/monitoring_hub/apps/metrics_reporter_ui/rel/metrics_reporter_ui /metrics_ui-src

WORKDIR /wallaroo-src

RUN make clean && \
    make target_cpu=x86-64 build-giles-all && \
    make target_cpu=x86-64 build-utils-all && \
    make target_cpu=x86-64 build-machida-all && \
    mkdir /wallaroo-bin && \
    cp giles/sender/sender /wallaroo-bin/sender && \
    cp giles/receiver/receiver /wallaroo-bin/receiver && \
    cp machida/build/machida /wallaroo-bin/machida && \
    cp utils/cluster_shutdown/cluster_shutdown /wallaroo-bin/cluster_shutdown && \
    cp docker-setup.sh /wallaroo-bin && \
    make clean


VOLUME /src/wallaroo

ENV PATH /wallaroo-bin:/metrics_ui-src/metrics_reporter_ui/bin:$PATH
ENV PYTHONPATH /src/wallaroo/machida:$PYTHONPATH

WORKDIR /src

ENTRYPOINT ["docker-setup.sh"]
