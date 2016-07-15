FROM ubuntu:15.10

# Set locale, elixir needs this
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

RUN apt-get update

RUN apt-get install -y openssl

RUN mkdir /apps && mkdir /apps/market_spread_reports_ui

COPY /rel/market_spread_reports_ui/releases/0.0.1/market_spread_reports_ui.tar.gz ./rel/market_spread_reports_ui.tar.gz

RUN tar xfv /rel/market_spread_reports_ui.tar.gz -C /apps/market_spread_reports_ui

EXPOSE 4001 5555

ENTRYPOINT ["/apps/market_spread_reports_ui/bin/market_spread_reports_ui", "foreground"]