FROM centos:7

RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
 && yum install -y make file which git wget unzip chrpath yum-plugin-versionlock \
 && wget https://packages.erlang-solutions.com/erlang-solutions-1.0-1.noarch.rpm \
 && rpm -Uvh erlang-solutions-1.0-1.noarch.rpm \
 && yum versionlock erlang-20.1 \
 && yum install -y npm erlang-20.1 \
 && wget https://github.com/elixir-lang/elixir/releases/download/v1.5.2/Precompiled.zip \
 && unzip Precompiled.zip \
 && rm -f Precompiled.zip \
 && rm -f epel-release-latest-7.noarch.rpm \
 && yum clean all \
 && rm -rf /var/cache/yum

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

