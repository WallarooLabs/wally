#!/bin/sh

for i in $MULTIPLE_KEYS_LIST; do
	if [ "$WALLAROO_TCP_SOURCE_SINK" = yes ]; then
		dd if=$WALLAROO_TOP/testing/data/market_spread/nbbo/r3k-symbols_nbbo-fixish.msg bs=1000000 count=1 | od -x | sed s/^/$i/ | sed -n '1,/^.3641060/p' | perl -ne 'print "\0\0\0"; print "1"; print' > /tmp/input-file.$i.txt
	else
		dd if=$WALLAROO_TOP/testing/data/market_spread/nbbo/r3k-symbols_nbbo-fixish.msg bs=1000000 count=4 | od -x | sed s/^/$i/ > /tmp/input-file.$i.txt
	fi
done
