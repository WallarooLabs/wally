FROM ubuntu:16.04

# Set locale, elixir needs this
RUN apt-get update && apt-get install -y locales
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

RUN apt-get update

RUN apt-get install -y openssl

RUN mkdir /apps && mkdir /apps/metrics_reporter_ui

COPY /_build/prod/rel/metrics_reporter_ui/releases/0.0.1/metrics_reporter_ui.tar.gz ./rel/metrics_reporter_ui.tar.gz

RUN tar xfv /rel/metrics_reporter_ui.tar.gz -C /apps/metrics_reporter_ui

EXPOSE 4000 5001

ENV PATH /apps/metrics_reporter_ui/bin:$PATH

ENTRYPOINT ["/apps/metrics_reporter_ui/bin/metrics_reporter_ui", "foreground"]
