#!/bin/sh

dd if=testing/data/market_spread/nbbo/r3k-symbols_nbbo-fixish.msg bs=1000000 count=4 | od -x | sed 's/^/T/' > /tmp/input-file.txt
cd testing/correctness/scripts/effectively-once
make -C ../../../.. PONYCFLAGS="--verbose=1 -d -Dresilience -Dtrace -Dcheckpoint_trace -Didentify_routing_ids" build-examples-pony-passthrough build-testing-tools-external_sender     build-utils-cluster_shrinker

./master-crasher.sh 3 crash1 crash2 crash-sink
