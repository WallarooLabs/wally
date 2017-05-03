# Wallaroo Metrics UI

## Overview

The Wallaroo Metrics UI is used to provide soft real time metric updates
on any connected and running Wallaroo application. The Metrics UI will show
metric stats on the Overall(Source to Sink) Pipeline, Worker, and Computation
levels.

Metric stats consist of both throughput and latency stats. Throughput history
is a count of events (as defined by their category) completed per second.
Throughput stats are shown as last 5 minute aggregates of the minimum, median,
and maximum. On our detailed metrics page we also have a graph of the the
median throughput per second for the last 5 minutes.

Latency is calculated using fixed bin histograms. Fixed bin histograms allow
for inexpensive processing on the Wallaroo side and give us the ability to
answer questions such as: What percentage of events completed in less than
x ms(or other unit of time)? Latency stats are shown as last 5 minute
aggregates of the latency that falls within the 50th Percentile Bin,
90th Percentile Bin, 95th Percentile Bin, 99th Percentile Bin, and
99.9th Percentile Bin.

### Page by Page Overview

#### Main page

The main page shows us which applications are currently connected to the
Monitoring Hub and will dynamically populate as an application connects.

<img src="\images\metrics-ui\main-page.png" width="1000px">

#### Application Dashboard

The application dashboard is broken into 3 sections and shows key throughput
and latency stats for each reporting element in it's category.

  - Overall(Start to End) Stats: these stats are reported for every pipeline
  within an application. Overall stats are calculated as the time it takes for
  a message to be processed as defined by the pipeline.

  - Worker Stats: these stats are reported for every worker that a given
  application is running on. Worker stats are calculated as the time from
  when a message arrives on a worker until it is processed or handed off to
  another worker.

  - Computation Stats: these stats are reported for every computation that
  is run within an application. Computation stats are calculated as the time
  it takes for that computation to complete for a given message.

<img src="\images\metrics-ui\application-dashboard.png" width="1000px">

#### Detailed Metrics

 Our detailed metrics pages is available for every element within the three
 categories. It shows our key latency and throughput stats, as well as two
 additional graphs. A "Percent by Latency Bin" graph is used to effectively
 show the percent of our latencies that fall within key latency bins. A
 "Throughput" graph is used to show the median throughput per second for the
 last 5 minutes of reported metrics. This allows the user to quickly see if
 there were any noticeable changes to the median throughput.

<img src="\images\metrics-ui\detailed-metrics.png" width="1000px">

The Wallaroo Metrics UI is accessible via port 4000 for HTTP and uses 5001 to
receive incoming TCP data from Wallaroo.

## Getting Started with the Metrics UI

If you'd rather run the Metrics UI using a prebuilt binary, jump ahead to the
[Prebuilt Binaries](#prebuilt-binaries) section.

If you'd rather run the Metrics UI using a prebuilt Docker image, jump ahead
to the [In Docker](#in-docker) section.

### Prebuilt Binaries

If you'd rather not build the Metrics UI from source, an alternative would
be to run the prebuilt binaries.

#### Prerequisites

The prebuilt binary depends on openssl version 1.0.x.

To install:
```
brew install openssl
```

NOTE: This is a keg-only install and will have no affect on any pre-existing
openssl installations unless you choose to symlink this version yourself.
Symlinking is not necessary to continue.

#### Download the Binaries

You can download the binaries from the following locations:

OSX:

```
https://s3.amazonaws.com/sendence-dev/wallaroo/metrics_reporter_ui/osx/metrics_reporter_ui-0.0.1.tar.gz
```

#### Running the Metrics UI

After extracting the above download, you can run the following:

```
cd ~/path/to/metrics_reporter_ui/bin
./metrics_reporter_ui start
```
To verify the Metrics UI started correctly, you can either run
`./metrics_reporter_ui ping` and you should get a `pong` back. Else if you are
running locally, open [http://localhost:4000](http://localhost:4000) in your
browser to verify the Metrics UI is up and running.

To restart or stop the Metrics UI you can run the following:

```
cd ~/path/to/metrics_reporter_ui/bin
./metrics_reporter_ui restart
```

```
cd ~/path/to/metrics_reporter_ui/bin
./metrics_reporter_ui stop
```


### In Docker

If you'd rather not build the UI from source, another alternative would
be to run our prebuilt docker image.

#### Installing Docker

If you do not already have Docker installed, you can follow the instructions
[here](https://docs.docker.com/docker-for-mac/) to get Docker setup on your
Mac.

#### Running the Metrics UI

Once you have Docker setup, you can grab the Metrics UI image by running:

```
docker pull sendence/wallaroo-metrics-ui:pre-0.0.1
```

To start the Metrics UI you will run:

```
docker run -d --name mui -p 0.0.0.0:4000:4000 -p 0.0.0.0:5001:5001 sendence/wallaroo-metrics-ui
```

If you are running locally, open [http://localhost:4000](http://localhost:4000)
in your browser to verify the Metrics UI is up and running.

To restart and stop the Metrics UI you can run the following:
`docker restart mui`
`docker stop mui`


## Building from Source

Note: This section is recommended for advanced users.

### Installing prerequisites for the Metrics UI

The Metrics UI is built using a Phoenix backend. In order to build from source
you will need the following:
  - Erlang 18.0
  - Elixir 1.2.0
  - Node 4.2.2
    - browserify, node-sass, watchify

 This guide assumes you are running OSX 10.10 (Yosemite) or newer.

#### Installing Erlang (v18.0)

The easiest way to install Erlang would be from the
[erlang-solutions](https://www.erlang-solutions.com/resources/download.html)
download page. [This](https://packages.erlang-solutions.com/erlang/esl-erlang/FLAVOUR_1_general/esl-erlang_18.0-1~osx~10.10_amd64.dmg)
is a direct link to Erlang 18.0 for OSX.

To verify that you've installed Erlang successfully, you can run `erl`
in the commandline and see a prompt similar to this:
```
Erlang/OTP 18 [erts-7.2.1] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Eshell V7.2.1  (abort with ^G)
```

#### Installing Elixir (v1.2.0)

You can download precompiled binaries [here](https://github.com/elixir-lang/elixir/releases/download/v1.2.0/Precompiled.zip).
Once downloaded and extracted, you can then add the Elixir bin path
to your PATH environment variable as such `export PATH="$PATH:/path/to/elixir/bin"`

To verify that you've installed Elixir successfully, you can run `iex`
in the commandline and see a prompt similar to this:
```
Erlang/OTP 18 [erts-7.2.1] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.2.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
```

##### Installing hex
To install `hex` you can run the following:
`mix local.hex`

#### Installing Node (v.4.2.2)

The easiest way to install Node would be to use nvm.

##### Installing NVM

You can follow the instructions [here](https://github.com/creationix/nvm#installation)
To install NVM on your machine.

##### Installing Node

Once `nvm` is successfully installed, you can install 4.2.2 with the following
command:
`nvm install v4.2.2`

And to use Node 4.2.2 run:
`nvm use v4.2.2`

##### Installing Node dependencies

To install the needed Node dependencies `browserify`, `watchify` and
`node-sass` run the following command:

```
npm install -g browserify watchify node-sass
```

## Building the Metrics UI

Once you've successfully installed the required prerequisites you can build
the Metrics UI with the following commands:

```
cd buffy/monitoring_hub
MIX_ENV=prod mix deps.get --only prod
cd buffy/monitoring_hub/apps/metrics_reporter_ui
MIX_ENV=prod mix compile
npm install
npm run build:production
MIX_ENV=prod mix phoenix.digest
MIX_ENV=prod mix release
```

## Running the Metrics UI

### Running a manually built Release

After successfully creating a release, the Metrics UI can be run with
the following commands:

```
cd buffy/monitoring_hub/apps/metrics_reporter_ui/rel/metrics_reporter_ui/bin
./metrics_reporter_ui start
```

If you are running locally, open [http://localhost:4000](http://localhost:4000)
in your browser to verify the Metrics UI is up and running.

To restart or stop the Metrics UI you can run the following:

```
cd buffy/monitoring_hub/apps/metrics_reporter_ui/rel/metrics_reporter_ui/bin
./metrics_reporter_ui restart
```

```
cd buffy/monitoring_hub/apps/metrics_reporter_ui/rel/metrics_reporter_ui/bin
./metrics_reporter_ui stop
```

