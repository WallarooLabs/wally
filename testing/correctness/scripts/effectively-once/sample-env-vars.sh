## When using sh/bash, use via: . /path/to/this/file

if [ -z "$1" ]; then
	echo ""
else
	export WALLAROO_TOP=$1
fi

if [ -z "$WALLAROO_TOP" ]; then
    export WALLAROO_TOP=$HOME/wallaroo
fi

## Assume: all Wallaroo workers are on the same machine via loopback interface
export WALLAROO_INIT_HOST=127.0.0.1

export WALLAROO_OUT_HOST=$WALLAROO_INIT_HOST
export WALLAROO_METRICS_HOST=$WALLAROO_INIT_HOST

export WALLAROO_IN_BASE=7100
export WALLAROO_CONTROL_BASE=7101
export WALLAROO_DATA_BASE=7102
export WALLAROO_MY_EXTERNAL_BASE=7103
export WALLAROO_MY_CONTROL_BASE=7104
export WALLAROO_MY_DATA_BASE=7105
export WALLAROO_OUT_PORT=7200

## export WALLAROO_BIN="$WALLAROO_TOP/examples/pony/passthrough/passthrough"
export WALLAROO_ARG_IN="InputBlobs@__IN_HOST__:__IN_PORT__:Dragons-Love-Tacos:500:50"
export WALLAROO_ARG_OUT="${WALLAROO_OUT_HOST}:${WALLAROO_OUT_PORT}"
export WALLAROO_ARG_METRICS="${WALLAROO_METRICS_HOST}:5001"
export WALLAROO_ARG_CONTROL="${WALLAROO_INIT_HOST}:${WALLAROO_CONTROL_BASE}"
export WALLAROO_ARG_DATA="${WALLAROO_INIT_HOST}:${WALLAROO_DATA_BASE}"
export WALLAROO_ARG_RESILIENCE="--run-with-resilience"
export WALLAROO_ARG_PONY="--ponynoblock --ponythreads=1 --ponyminthreads=9999"

export WALLAROO_ARG_PT="--verbose --parallelism 20 --source connector --parallelism 10 --key-by first-byte --step asis-state --sink connector"

export WALLAROO_BASE_ARGS="$WALLAROO_ARG_PT --out $WALLAROO_ARG_OUT --metrics $WALLAROO_ARG_METRICS --control $WALLAROO_ARG_CONTROL $WALLAROO_ARG_RESILIENCE"

if [ -z "$MULTIPLE_KEYS_LIST" ]; then
	export MULTIPLE_KEYS_LIST="A B C D E F G H I J"
fi
