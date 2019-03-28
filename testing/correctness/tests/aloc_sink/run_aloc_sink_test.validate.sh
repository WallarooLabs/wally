#!/bin/sh

IN1=/tmp/aloc_sink.out.txnlog
IN=/tmp/aloc_sink.out.txnlog.short

if [ ! -f $IN1 ]; then
	echo Error: input file $IN1 does not exist
	exit 1
fi

# Clean up the file's transaction names a bit
cat $IN1 | sed 's/worker-initializer-id-[0-9]*://' > $IN

# We expect rollbacks to happen for these checkpoint_ids
for c in 3 6 9 15; do
	pat="c_id=$c.,"
	egrep $pat $IN | grep '2-ok' > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo Error: unexpected phase 2-ok for checkpoint $c
		cat $IN; exit 1
	fi
	egrep $pat $IN | grep '2-rollback' > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo Error: phase 2-rollback not found for checkpoint $c
		cat $IN; exit 1
	fi
done

# We expect commits to happen for these checkpoint_ids
# There may be more checkpoints after 18, but we won't check
# because test timing can affect how many checkpoints may follow.
# Also, 18 is the last checkpoint that aloc_sink.abort-rules
# will affect.
for c in 1 2 4 5 7 8 10 11 12 13 14 16 17 18; do
	pat="c_id=$c.,"
	egrep $pat $IN | grep '2-rollback' > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo Error: unexpected phase 2-rollback for checkpoint $c
		cat $IN; exit 1
	fi
	egrep $pat $IN | grep '2-ok' > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo Error: phase 2-ok not found for checkpoint $c
		cat $IN; exit 1
	fi
done

echo "Validation of $IN1 was successful"
exit 0

